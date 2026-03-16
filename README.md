# Stock Movers Pipeline

A fully serverless AWS pipeline that tracks the biggest daily mover from a tech stock watchlist and displays the history on a live dashboard.

**Live Dashboard:** [http://stock-movers-frontend-prod.s3-website-us-east-1.amazonaws.com](http://stock-movers-frontend-prod.s3-website-us-east-1.amazonaws.com)

---

## Architecture

```
EventBridge (cron: 9pm UTC)
    │
    ▼
Lambda: Ingestor
    │  Fetches all 6 stocks from Polygon.io API
    │  Calculates % change and market volatility
    │  Stores daily winner to DynamoDB
    ▼
DynamoDB (stock-movers-table)
    │
    ▼
Lambda: Retriever ◄── API Gateway (GET /movers)
                              │
                              ▼
                    S3 Static Website (Frontend SPA)
```

### Services Used

- **EventBridge** — daily cron trigger at 9pm UTC (after market close)
- **Lambda (Ingestor)** — fetches stock data, calculates winner, writes to DB
- **Lambda (Retriever)** — reads last 7 days from DB, returns clean JSON
- **DynamoDB** — stores one record per day (date as partition key)
- **API Gateway** — REST API exposing GET /movers
- **S3** — hosts the frontend SPA
- **Secrets Manager** — stores Polygon.io API key securely at runtime
- **CloudWatch** — log groups for both Lambda functions

---

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.0 installed
- Python 3.11+
- A free [Polygon.io](https://polygon.io) account and API key

---

## Deploy

**1. Clone the repo**

```bash
git clone https://github.com/viholden/pennymac-pipeline.git
cd pennymac-pipeline
```

**2. Create your tfvars file (never committed)**

```bash
cat > infra/terraform.tfvars << EOF
massive_api_key = "your_polygon_api_key_here"
EOF
```

**3. Deploy all infrastructure**

```bash
cd infra
terraform init
terraform apply -var-file="terraform.tfvars"
```

**4. Note your outputs**

```
api_endpoint           = "https://[id].execute-api.us-east-1.amazonaws.com/prod/movers"
frontend_url           = "http://stock-movers-frontend-prod.s3-website-us-east-1.amazonaws.com"
ingestor_function_name = "stock-movers-ingestor"
```

**5. Update the API URL in the frontend**

Open `frontend/index.html` and set `API_URL` to your api_endpoint output.

**6. Deploy the frontend**

```bash
aws s3 sync frontend/ s3://stock-movers-frontend-prod --delete
```

**7. Test the ingestor manually**

```bash
aws lambda invoke \
  --function-name stock-movers-ingestor \
  --payload '{}' \
  response.json && cat response.json
```

---

## CI/CD

Every push to `main` automatically:

1. Runs `terraform plan`
2. Runs `terraform apply`
3. Syncs the frontend to S3

AWS credentials are stored as GitHub Actions secrets — never in code.

---

## API Reference

### GET /movers

Returns the last 7 days of top movers.

**Response 200:**

```json
{
  "count": 7,
  "data": [
    {
      "date": "2026-03-15",
      "ticker": "AAPL",
      "pct_change": -2.098,
      "close_price": 250.12,
      "direction": "loss",
      "volatility": "Medium",
      "volatility_spread": 3.45
    }
  ]
}
```

**Error responses:**

- `404` — no data found for the last 7 days
- `500` — internal server error (check CloudWatch logs)

---

## Security

- API keys stored in **AWS Secrets Manager**, fetched at Lambda runtime
- IAM roles follow **least privilege**:
  - Ingestor: `dynamodb:PutItem` + `secretsmanager:GetSecretValue` only
  - Retriever: `dynamodb:GetItem`, `Query`, `Scan` only
- No secrets committed to git (`.env` and `*.tfvars` are gitignored)
- CloudWatch log groups retain logs for 7 days

---

## Trade-offs & Decisions

**DynamoDB over RDS** — The data model is simple (one record per day, queried by date). DynamoDB's on-demand billing means zero cost at this scale and keeps the architecture fully serverless. RDS would add ~$15/month minimum and require VPC configuration.

**Terraform over CDK** — Terraform is language-agnostic and easier to read across teams without requiring TypeScript/Python knowledge. The tradeoff is that CDK would offer stronger type safety and IDE support.

**S3 static hosting over Amplify** — Simpler to configure and deploy via CI/CD script. Amplify adds value for larger apps needing auth and routing, but is overkill for a single-page dashboard.

**Remote Terraform state in S3** — State is stored in S3 with DynamoDB locking to prevent concurrent apply conflicts. This allows both local development and CI/CD to share the same state safely. The tradeoff is added complexity during initial setup compared to local state files.

**Single IAM role for both Lambdas** — Both functions share one execution role with separate inline policies. In a larger system, each Lambda would have its own dedicated role for stricter isolation.

---

## Project Structure

```
├── infra/                  # All Terraform IaC
│   ├── main.tf
│   ├── variables.tf
│   ├── dynamodb.tf
│   ├── lambda.tf
│   ├── eventbridge.tf
│   ├── apigateway.tf
│   ├── secrets.tf
│   ├── s3.tf
│   └── outputs.tf
├── lambdas/
│   ├── ingestor/           # Daily stock fetcher
│   │   └── handler.py
│   └── retriever/          # API data server
│       └── handler.py
├── frontend/
│   └── index.html          # Single page dashboard
├── .github/
│   └── workflows/
│       └── deploy.yml      # CI/CD pipeline
└── README.md
```

---

## Bonus Feature: Market Volatility Badge

The dashboard displays a **volatility indicator** showing daily market spread across the 6-stock watchlist:

- **High Volatility** (≥5% spread) — Red badge
- **Medium Volatility** (2-5% spread) — Yellow badge
- **Low Volatility** (<2% spread) — Green badge

This provides at-a-glance insight into market behavior beyond just the single biggest mover.

---

## Local Testing

**Test the ingestor locally:**

```bash
cd lambdas/ingestor
python test_local.py
```

**Test the API locally:**

```bash
python test_api.py
```

**View CloudWatch logs:**

```bash
aws logs tail /aws/lambda/stock-movers-ingestor --follow
```

---

## Cleanup

To destroy all AWS resources:

```bash
cd infra
terraform destroy -var-file="terraform.tfvars"
```

Note: Make sure to delete the S3 state bucket manually if you want to completely remove all resources.
