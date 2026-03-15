"""
Run this to test the retriever locally.
Seeds fake DynamoDB data so you can see the response shape.
"""
import os
from unittest.mock import MagicMock, patch
from datetime import datetime, timedelta, timezone

# Generate fake data for the last 3 days
today = datetime.now(timezone.utc).date()
dates = [str(today - timedelta(days=i)) for i in range(3)]

# Fake DynamoDB data — simulates 3 days of stored results
FAKE_ITEMS = [
    {"date": dates[0], "ticker": "NVDA", "pct_change": "4.72",  "close_price": "487.33", "direction": "gain"},
    {"date": dates[1], "ticker": "TSLA", "pct_change": "-3.18", "close_price": "251.10", "direction": "loss"},
    {"date": dates[2], "ticker": "AAPL", "pct_change": "1.95",  "close_price": "219.44", "direction": "gain"},
]

def fake_get_item(Key):
    date = Key["date"]
    match = next((i for i in FAKE_ITEMS if i["date"] == date), None)
    return {"Item": match} if match else {}

mock_table = MagicMock()
mock_table.get_item = MagicMock(side_effect=fake_get_item)

with patch("boto3.resource") as mock_boto:
    mock_boto.return_value.Table.return_value = mock_table
    import handler
    result = handler.handler({}, {})

import json
print("\n── HTTP Status ──")
print(result["statusCode"])
print("\n── Response Body ──")
print(json.dumps(json.loads(result["body"]), indent=2))
