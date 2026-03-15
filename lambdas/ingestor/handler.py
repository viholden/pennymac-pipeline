import json
import os
import time
import urllib.request
import urllib.error
import boto3
from datetime import datetime, timezone

# Constants
WATCHLIST = ["AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "NVDA"]
TABLE_NAME = os.environ.get("DYNAMODB_TABLE", "stock-movers")
API_KEY    = os.environ.get("MASSIVE_API_KEY")

# DynamoDB client
dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
table    = dynamodb.Table(TABLE_NAME)


# Retry logic with exponential backoff 
def fetch_with_retry(url: str, max_retries: int = 3) -> dict:
    """
    Fetch a URL and return parsed JSON.
    Retries up to max_retries times with exponential backoff.
    Delays: 1s → 2s → 4s
    """
    delay = 1
    last_error = None

    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                return json.loads(response.read())

        except urllib.error.HTTPError as e:
            last_error = e
            if e.code != 429 and 400 <= e.code < 500:
                print(f"[{attempt+1}] HTTP {e.code} for {url} — not retrying")
                raise

            print(f"[{attempt+1}] HTTP {e.code} — retrying in {delay}s")

        except Exception as e:
            last_error = e
            print(f"[{attempt+1}] Error: {e} — retrying in {delay}s")

        time.sleep(delay)
        delay *= 2 

    raise Exception(f"All {max_retries} attempts failed. Last error: {last_error}")


# Fetch one stock
def fetch_stock(ticker: str) -> dict:
    """
    Fetch previous day open/close for a ticker.
    Returns dict with ticker, open, close, pct_change.
    """
    url = (
        f"https://api.polygon.io/v2/aggs/ticker/{ticker}/prev"
        f"?apiKey={API_KEY}"
    )
    data = fetch_with_retry(url)

    result = data["results"][0]
    open_price  = result["o"]
    close_price = result["c"]
    pct_change  = ((close_price - open_price) / open_price) * 100

    return {
        "ticker":      ticker,
        "open":        open_price,
        "close":       close_price,
        "pct_change":  round(pct_change, 4),
        "abs_change":  round(abs(pct_change), 4),
    }


# Lambda entry point
def handler(event, context):
    print(f"Starting ingestor run — watchlist: {WATCHLIST}")

    results  = []
    errors   = []

    for ticker in WATCHLIST:
        try:
            stock = fetch_stock(ticker)
            results.append(stock)
            print(f"  {ticker}: {stock['pct_change']:+.2f}%")
        except Exception as e:
            errors.append(ticker)
            print(f"  {ticker}: FAILED — {e}")

    # Need at least one successful fetch to continue
    if not results:
        raise Exception(f"All tickers failed: {errors}")

    # Find the biggest mover (highest absolute % change)
    winner = max(results, key=lambda x: x["abs_change"])
    direction = "gain" if winner["pct_change"] > 0 else "loss"
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    # Save to DynamoDB
    item = {
        "date":        today,
        "ticker":      winner["ticker"],
        "pct_change":  str(round(winner["pct_change"], 4)),
        "close_price": str(round(winner["close"], 2)),
        "direction":   direction,
    }

    table.put_item(Item=item)
    print(f"Saved winner: {winner['ticker']} ({winner['pct_change']:+.2f}%) on {today}")

    if errors:
        print(f"Warning: failed tickers (skipped): {errors}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "date":    today,
            "winner":  winner["ticker"],
            "change":  winner["pct_change"],
            "skipped": errors,
        })
    }
