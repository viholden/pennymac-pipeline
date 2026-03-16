import json
import os
import boto3
from boto3.dynamodb.conditions import Key
from datetime import datetime, timedelta, timezone

# Constants
TABLE_NAME = os.environ.get("DYNAMODB_TABLE", "stock-movers")
DAYS_TO_RETURN = 7

# DynamoDB client
dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
table    = dynamodb.Table(TABLE_NAME)


# Helpers
def build_response(status_code: int, body: dict) -> dict:
    """
    Builds a properly formatted API Gateway response.
    Always returns correct headers so the frontend can read it.
    """
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type":                "application/json",
            "Access-Control-Allow-Origin": "*",  
        },
        "body": json.dumps(body),
    }


def get_last_n_dates(n: int) -> list:
    """Returns last N calendar dates as 'YYYY-MM-DD' strings."""
    today = datetime.now(timezone.utc).date()
    return [
        str(today - timedelta(days=i))
        for i in range(n)
    ]


# Lambda entry point
def handler(event, context):
    print("Retriever called — fetching last 7 days from DynamoDB")

    try:
        dates  = get_last_n_dates(DAYS_TO_RETURN)
        movers = []

        for date in dates:
            response = table.get_item(Key={"date": date})
            item = response.get("Item")
            if item:
                movers.append({
                    "date":              item["date"],
                    "ticker":            item["ticker"],
                    "pct_change":        float(item["pct_change"]),
                    "close_price":       float(item["close_price"]),
                    "direction":         item["direction"],
                    "volatility":        item.get("volatility", "Unknown"),        # .get() handles old records
                    "volatility_spread": float(item.get("volatility_spread", 0)),  # .get() handles old records
                })

        # Sort newest first
        movers.sort(key=lambda x: x["date"], reverse=True)

        print(f"Returning {len(movers)} records")

        if not movers:
            return build_response(404, {
                "message": "No data found for the last 7 days.",
                "data":    [],
            })

        return build_response(200, {
            "count": len(movers),
            "data":  movers,
        })

    except Exception as e:
        print(f"Retriever error: {e}")
        return build_response(500, {
            "message": "Internal server error",
            "error":   str(e),
        })
