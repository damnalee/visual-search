import importlib

packages = [
    "torch",
    "torchvision",
    "transformers",
    "chromadb",
    "fastapi",
    "uvicorn",
    "PIL",
    "pandas",
    "multipart",
]

for name in packages:
    try:
        module = importlib.import_module(name)
        version = getattr(module, "__version__", "ok")
        print(f"OK      {name} {version}")
    except Exception as error:
        print(f"MISSING {name} -> {error}")