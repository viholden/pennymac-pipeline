import os
import urllib.request
import json
import time

# Load .env file manually if MASSIVE_API_KEY not set
if not os.getenv("MASSIVE_API_KEY"):
    try:
        with open(".env") as f:
            for line in f:
                if line.strip() and not line.startswith("#"):
                    key, value = line.strip().split("=", 1)
                    os.environ[key] = value
    except FileNotFoundError:
        print("Warning: .env file not found. Make sure MASSIVE_API_KEY is set.")

API_KEY = os.getenv("MASSIVE_API_KEY")
WATCHLIST = ["AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "NVDA"]

for ticker in WATCHLIST:
    url = f"https://api.polygon.io/v2/aggs/ticker/{ticker}/prev?apiKey={API_KEY}"
    try:
        with urllib.request.urlopen(url) as response:
            data = json.loads(response.read())
            result = data["results"][0]
            o, c = result["o"], result["c"]
            pct = ((c - o) / o) * 100
            print(f"{ticker}: open={o}, close={c}, change={pct:.2f}%")
        time.sleep(0.5)
    except urllib.error.HTTPError as e:
        print(f"{ticker}: Error - {e.code} {e.reason}")
