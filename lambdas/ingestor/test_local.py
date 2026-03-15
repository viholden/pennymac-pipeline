"""
Run this to test the ingestor logic locally.
Mocks DynamoDB so no AWS connection needed.
Uses your real Massive API key from .env
"""
import os
import sys
from unittest.mock import MagicMock, patch

# Load .env manually (no dotenv library needed)
with open("../../.env") as f:
    for line in f:
        if "=" in line and not line.startswith("#"):
            k, v = line.strip().split("=", 1)
            os.environ[k] = v

# Mock out the DynamoDB table so nothing actually writes
mock_table = MagicMock()
mock_table.put_item = MagicMock(return_value={})

with patch("boto3.resource") as mock_boto:
    mock_boto.return_value.Table.return_value = mock_table
    import handler
    result = handler.handler({}, {})

print("\n── Result ──────────────────────")
print(result)
print("\n── DynamoDB would have written ──")
print(mock_table.put_item.call_args)
