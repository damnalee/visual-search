import asyncio
from contextlib import asynccontextmanager
from io import BytesIO
from pathlib import Path
from typing import Optional

import chromadb
import torch
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel
from starlette.concurrency import run_in_threadpool
from transformers import CLIPModel, CLIPProcessor

CLIP_NAME = "openai/clip-vit-base-patch32"
IMAGES_DIR = Path("data/fashion/images")

REQUEST_TIMEOUT_SECONDS = 15
MAX_UPLOAD_BYTES = 5 * 1024 * 1024

# Auto threshold = max(FLOOR, best_score - MARGIN)
TEXT_FLOOR = 0.18
TEXT_MARGIN = 0.05
IMAGE_FLOOR = 0.50
IMAGE_MARGIN = 0.10

state = {}


def to_tensor(out):
    return out if isinstance(out, torch.Tensor) else out.pooler_output


@asynccontextmanager
async def lifespan(app: FastAPI):
    device = "cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu"
    state["device"] = device
    state["model"] = CLIPModel.from_pretrained(CLIP_NAME).to(device).eval()
    state["processor"] = CLIPProcessor.from_pretrained(CLIP_NAME)
    client = chromadb.PersistentClient(path="chroma_db")
    state["collection"] = client.get_collection("products")
    print("Ready. Device:", device, "Items:", state["collection"].count())
    yield
    state.clear()


app = FastAPI(title="Visual Search API", lifespan=lifespan)

# Dev setting: allow any origin. Restrict to your real frontend origin in production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

if IMAGES_DIR.exists():
    app.mount("/images", StaticFiles(directory=str(IMAGES_DIR)), name="images")


class TextQuery(BaseModel):
    query: str
    top_k: int = 10
    threshold: Optional[float] = None  # None = auto-tune
    color: Optional[str] = None


def embed_text(text: str):
    inputs = state["processor"](
        text=[text], return_tensors="pt", padding=True, truncation=True, max_length=77
    ).to(state["device"])
    with torch.no_grad():
        out = state["model"].get_text_features(**inputs)
    emb = torch.nn.functional.normalize(to_tensor(out), dim=-1)
    return emb.cpu().tolist()[0]


def embed_image(image: Image.Image):
    inputs = state["processor"](images=[image], return_tensors="pt").to(state["device"])
    with torch.no_grad():
        out = state["model"].get_image_features(**inputs)
    emb = torch.nn.functional.normalize(to_tensor(out), dim=-1)
    return emb.cpu().tolist()[0]


def search(embedding, top_k: int, color: Optional[str]):
    where = {"color": color.strip().title()} if color and color.strip() else None
    res = state["collection"].query(
        query_embeddings=[embedding],
        n_results=top_k,
        where=where,
        include=["metadatas", "distances"],
    )
    results = []
    for item_id, meta, dist in zip(res["ids"][0], res["metadatas"][0], res["distances"][0]):
        results.append(
            {
                "id": item_id,
                "score": round(1.0 - dist, 4),  # cosine distance -> similarity
                "name": meta.get("name"),
                "category": meta.get("category"),
                "article": meta.get("article"),
                "color": meta.get("color"),
                "image_url": f"/images/{item_id}.jpg",
            }
        )
    return results


def filter_results(results, threshold: Optional[float], floor: float, margin: float):
    if threshold is not None:
        cut = threshold
    elif results:
        cut = max(floor, results[0]["score"] - margin)
    else:
        cut = floor
    kept = [r for r in results if r["score"] >= cut]
    return kept, round(cut, 4)


def run_text_search(query: str, top_k: int, color: Optional[str], threshold: Optional[float]):
    results = search(embed_text(query), top_k, color)
    results, cut = filter_results(results, threshold, TEXT_FLOOR, TEXT_MARGIN)
    return {"query": query, "threshold_used": cut, "count": len(results), "results": results}


def run_image_search(image: Image.Image, top_k: int, color: Optional[str], threshold: Optional[float]):
    results = search(embed_image(image), top_k, color)
    results, cut = filter_results(results, threshold, IMAGE_FLOOR, IMAGE_MARGIN)
    return {"threshold_used": cut, "count": len(results), "results": results}


async def run_with_timeout(fn, *args):
    try:
        return await asyncio.wait_for(run_in_threadpool(fn, *args), timeout=REQUEST_TIMEOUT_SECONDS)
    except asyncio.TimeoutError:
        raise HTTPException(status_code=504, detail="Search timed out. Try again.")


@app.get("/health")
def health():
    return {"status": "ok", "items": state["collection"].count(), "device": state["device"]}


@app.get("/colors")
def colors():
    metas = state["collection"].get(include=["metadatas"])["metadatas"]
    return {"colors": sorted({m.get("color") for m in metas if m.get("color")})}


@app.post("/search/text")
async def search_text(body: TextQuery):
    if not body.query.strip():
        raise HTTPException(status_code=400, detail="Query is empty")
    if not 1 <= body.top_k <= 50:
        raise HTTPException(status_code=400, detail="top_k must be 1-50")
    return await run_with_timeout(run_text_search, body.query, body.top_k, body.color, body.threshold)


@app.post("/search/image")
async def search_image(
    file: UploadFile = File(...),
    top_k: int = Form(10),
    threshold: Optional[float] = Form(None),
    color: Optional[str] = Form(None),
):
    if not 1 <= top_k <= 50:
        raise HTTPException(status_code=400, detail="top_k must be 1-50")
    data = await file.read()
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Image larger than 5 MB")
    try:
        image = Image.open(BytesIO(data)).convert("RGB")
    except (UnidentifiedImageError, OSError):
        raise HTTPException(status_code=400, detail="File is not a valid image")
    return await run_with_timeout(run_image_search, image, top_k, color, threshold)