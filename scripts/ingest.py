import pandas as pd
import torch
import chromadb
from pathlib import Path
from PIL import Image
from transformers import CLIPModel, CLIPProcessor

DATA_DIR = Path("data/fashion")
IMAGES_DIR = DATA_DIR / "images"
LIMIT = 8000
BATCH_SIZE = 32
MODEL_NAME = "openai/clip-vit-base-patch32"

device = "cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu"
print("Device:", device)

model = CLIPModel.from_pretrained(MODEL_NAME).to(device).eval()
processor = CLIPProcessor.from_pretrained(MODEL_NAME)

df = pd.read_csv(DATA_DIR / "styles.csv", on_bad_lines="skip")
df = df[df["id"].apply(lambda i: (IMAGES_DIR / f"{i}.jpg").exists())]
df = df.sample(n=min(LIMIT, len(df)), random_state=42)
print("Images to embed:", len(df))

client = chromadb.PersistentClient(path="chroma_db")
collection = client.get_or_create_collection("products", metadata={"hnsw:space": "cosine"})

for start in range(0, len(df), BATCH_SIZE):
    batch = df.iloc[start:start + BATCH_SIZE]
    images = [Image.open(IMAGES_DIR / f"{i}.jpg").convert("RGB") for i in batch["id"]]
    inputs = processor(images=images, return_tensors="pt").to(device)
    with torch.no_grad():
        out = model.get_image_features(**inputs)
    emb = out if isinstance(out, torch.Tensor) else out.pooler_output
    emb = torch.nn.functional.normalize(emb, dim=-1).cpu().tolist()
    collection.upsert(
        ids=[str(i) for i in batch["id"]],
        embeddings=emb,
        metadatas=[
            {
                "name": str(r.productDisplayName),
                "category": str(r.masterCategory),
                "article": str(r.articleType),
                "color": str(r.baseColour),
            }
            for r in batch.itertuples()
        ],
    )
    print(f"{start + len(batch)}/{len(df)}")

print("Done. Total items:", collection.count())