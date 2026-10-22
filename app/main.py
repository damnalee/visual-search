from contextlib import asynccontextmanager
from io import BytesIO
from pathlib import Path
from typing import Optional

import chromadb
import torch
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.staticfiles import StaticFiles
from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel
from transformers import CLIPModel, CLIPProcessor

MODEL_NAME = "openai/clip-vit-base-patch32"
IMAGES_DIR = Path("data/fashion/images")
DEFAULT_TEXT_THRESHOLD = 0.20
DEFAULT_IMAGE_THRESHOLD = 0.60

state = {}


def to_tensor(out):
    return out if isinstance(out, torch.Tensor) else out.pooler_output


@asynccontextmanager
async def lifespan(app: FastAPI):
    device = "cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu"
    state["device"] = device
    state["model"] = CLIPModel.from_pretrained(MODEL_NAME).to(device).eval()
    state["processor"] = CLIPProcessor.from_pretrained(MODEL_NAME)
    client = chromadb.PersistentClient(path="chroma_db")
    state["collection"] = client.get_collection("products")
    print("Ready. Device:", device, "Items:", state["collection"].count())
    yield
    state.clear()


app = FastAPI(title="Visual Search API", lifespan=lifespan)

if IMAGES_DIR.exists():
    app.mount("/images", StaticFiles(directory=str(IMAGES_DIR)), name="images")


class TextQuery(BaseModel):
    query: str
    top_k: int = 10
    threshold: float = DEFAULT_TEXT_THRESHOLD
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


def search(embedding, top_k: int, threshold: float, color: Optional[str] = None):
    where = {"color": color.strip().title()} if color and color.strip() else None
    res = state["collection"].query(
        query_embeddings=[embedding],
        n_results=top_k,
        where=where,
        include=["metadatas", "distances"],
    )
    results = []
    for item_id, meta, dist in zip(res["ids"][0], res["metadatas"][0], res["distances"][0]):
        score = 1.0 - dist  # cosine distance -> similarity
        if score < threshold:
            continue
        results.append(
            {
                "id": item_id,
                "score": round(score, 4),
                "name": meta.get("name"),
                "category": meta.get("category"),
                "article": meta.get("article"),
                "color": meta.get("color"),
                "image_url": f"/images/{item_id}.jpg",
            }
        )
    return results


@app.get("/health")
def health():
    return {"status": "ok", "items": state["collection"].count(), "device": state["device"]}


@app.get("/colors")
def colors():
    metas = state["collection"].get(include=["metadatas"])["metadatas"]
    return {"colors": sorted({m.get("color") for m in metas if m.get("color")})}


@app.post("/search/text")
def search_text(body: TextQuery):
    if not body.query.strip():
        raise HTTPException(status_code=400, detail="Query is empty")
    if not 1 <= body.top_k <= 50:
        raise HTTPException(status_code=400, detail="top_k must be 1-50")
    results = search(embed_text(body.query), body.top_k, body.threshold, body.color)
    return {"query": body.query, "threshold": body.threshold, "count": len(results), "results": results}


@app.post("/search/image")
async def search_image(
    file: UploadFile = File(...),
    top_k: int = Form(10),
    threshold: float = Form(DEFAULT_IMAGE_THRESHOLD),
    color: Optional[str] = Form(None),
):
    if not 1 <= top_k <= 50:
        raise HTTPException(status_code=400, detail="top_k must be 1-50")
    data = await file.read()
    try:
        image = Image.open(BytesIO(data)).convert("RGB")
    except (UnidentifiedImageError, OSError):
        raise HTTPException(status_code=400, detail="File is not a valid image")
    results = search(embed_image(image), top_k, threshold, color)
    return {"threshold": threshold, "count": len(results), "results": results}