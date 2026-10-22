import statistics
import time

import requests

URL = "http://127.0.0.1:8000/search/text"
QUERIES = [
    "red running shoes",
    "black leather handbag",
    "blue denim jeans",
    "white cotton t-shirt",
    "gold wrist watch",
    "men formal shirt",
    "sports sandals",
    "green kurta",
    "silver earrings",
    "brown belt",
]

# warm-up request, not counted
requests.post(URL, json={"query": "warm up", "top_k": 10}, timeout=60)

latencies = []
for query in QUERIES * 3:
    start = time.perf_counter()
    response = requests.post(URL, json={"query": query, "top_k": 10}, timeout=30)
    response.raise_for_status()
    latencies.append((time.perf_counter() - start) * 1000)

latencies.sort()
print(f"Requests: {len(latencies)}")
print(f"Median: {statistics.median(latencies):.0f} ms")
print(f"p95: {latencies[int(len(latencies) * 0.95) - 1]:.0f} ms")
print(f"Max: {latencies[-1]:.0f} ms")