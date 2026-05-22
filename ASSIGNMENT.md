# Notice Board — Assignment

## Overview

You are given a working Notice Board application with a React frontend and a Python Lambda backend.
Your job is to **deploy it to AWS** and progressively improve the deployment across 3 tiers.

The application is already built. You do not need to write frontend or backend code.
Your focus is entirely on **infrastructure, deployment, and automation**.

---

## What You Are Given

| File | Description |
|------|-------------|
| `frontend/` | React app (already built — do not modify) |
| `backend/lambda_function.py` | Python Lambda handler (already built — do not modify) |
| `backend/requirements.txt` | Python dependencies |
| `build.py` | Script to package the Lambda zip |

---

## Architecture

```
User's Browser
      │
      ├── Page Load ──────────────▶ Frontend Hosting (you decide where)
      │
      └── API Calls ──────────────▶ API Gateway ──▶ Lambda ──▶ MongoDB on EC2
```

---

## Before You Start

Make sure you have:
- [ ] AWS CLI configured (`aws configure`)
- [ ] Terraform installed
- [ ] Node.js 18+ installed
- [ ] Python 3 installed
- [ ] MongoDB running on EC2 (from Lab — Lambda MongoDB EC2)
- [ ] A GitHub account

---

## Tier 1 — Manual Deployment

**Goal:** Deploy the app manually using Terraform and AWS CLI. No automation yet.

### What to build

- An **S3 bucket** configured for static website hosting (public read access)
- A **Lambda function** running the Python backend
- An **API Gateway** (HTTP API) connected to the Lambda
- All resources named with your name as a prefix (e.g. `student-john-smith-notice-board`)

### Steps

1. Run `python build.py` to create `backend/lambda.zip`
2. Write `terraform/main.tf`, `terraform/variables.tf`, `terraform/outputs.tf`
3. Run `terraform init` and `terraform apply`
4. Build the React frontend with the API URL injected as `VITE_API_URL`
5. Upload the built frontend to S3 using the AWS CLI

### Acceptance Criteria

- [ ] Opening the S3 website URL shows the Notice Board UI
- [ ] Posting a notice saves it to MongoDB and appears on the page
- [ ] Deleting a notice removes it from the list
- [ ] All AWS resources are prefixed with `student-<your-name>`

### Hints

<details>
<summary>Hint — S3 static website</summary>

You need three things for a public S3 static website:
- `aws_s3_bucket`
- `aws_s3_bucket_public_access_block` with all `block_*` set to `false`
- `aws_s3_bucket_policy` allowing `s3:GetObject` for `Principal: "*"`
- `aws_s3_bucket_website_configuration` with `index_document = "index.html"`

</details>

<details>
<summary>Hint — Lambda zip</summary>

Run `python build.py` first. This creates `backend/lambda.zip`.
Terraform reads this file with `filename = "${path.module}/../backend/lambda.zip"`.

</details>

<details>
<summary>Hint — VITE_API_URL</summary>

Vite bakes environment variables into the build. Set it before running `npm run build`:

Mac/Linux: `VITE_API_URL=https://your-api-url npm run build`
Windows: `set VITE_API_URL=https://your-api-url` then `npm run build`

</details>

<details>
<summary>Hint — Upload to S3</summary>

```bash
aws s3 sync dist/ s3://<your-bucket-name>/ --delete
```

</details>

---

## Tier 2 — Automate with GitHub Actions

**Goal:** Eliminate the manual deploy steps. Every push to `main` automatically deploys both the backend and frontend.

### What to build

A GitHub Actions workflow file at `.github/workflows/deploy.yml` that:

1. Triggers on every push to the `main` branch
2. Packages and deploys the Lambda zip to AWS
3. Builds the React frontend (with `VITE_API_URL` set)
4. Uploads the built frontend to S3

### GitHub Secrets to configure

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions** and add:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `AWS_REGION` | `us-east-1` |
| `LAMBDA_FUNCTION_NAME` | Your Lambda function name from Terraform output |
| `S3_BUCKET` | Your S3 bucket name from Terraform output |
| `VITE_API_URL` | Your API Gateway URL from Terraform output |

### Acceptance Criteria

- [ ] Pushing a change to `main` triggers the workflow automatically
- [ ] The workflow completes without errors
- [ ] The updated app is live without any manual AWS CLI commands

### Hints

<details>
<summary>Hint — Workflow structure</summary>

```yaml
name: Deploy Notice Board

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # configure AWS credentials
      # deploy backend (build zip, update Lambda)
      # deploy frontend (npm install, npm run build, s3 sync)
```

</details>

<details>
<summary>Hint — Configure AWS credentials</summary>

Use the official AWS action:
```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ secrets.AWS_REGION }}
```

</details>

<details>
<summary>Hint — Update Lambda from workflow</summary>

```bash
pip install pymongo -t backend/_build -q
cp backend/lambda_function.py backend/_build/
cd backend/_build && zip -r ../lambda.zip .
aws lambda update-function-code \
  --function-name ${{ secrets.LAMBDA_FUNCTION_NAME }} \
  --zip-file fileb://backend/lambda.zip
```

</details>

---

## Tier 3 — Add a CDN with CloudFront

**Goal:** Put CloudFront in front of the S3 bucket to serve the frontend over HTTPS with global edge caching.

### What to build

Modify your Terraform to add:

- A **CloudFront Origin Access Control (OAC)**
- A **CloudFront distribution** pointing to the S3 bucket
- Update the **S3 bucket policy** to allow access only from CloudFront (not public)
- Update the **S3 public access block** to block all public access
- Add a **cache invalidation** step in your GitHub Actions workflow after each frontend deploy

### Acceptance Criteria

- [ ] The app loads over **HTTPS** via the CloudFront URL
- [ ] The S3 bucket is **no longer publicly accessible** directly
- [ ] Pushing to `main` triggers a CloudFront cache invalidation automatically
- [ ] The site loads fast from different locations (use browser DevTools → Network to check)

### Hints

<details>
<summary>Hint — CloudFront OAC resource</summary>

```hcl
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
```

</details>

<details>
<summary>Hint — S3 bucket policy for CloudFront OAC</summary>

The bucket policy Principal must be `cloudfront.amazonaws.com` with a condition matching the CloudFront distribution ARN:

```json
{
  "Principal": { "Service": "cloudfront.amazonaws.com" },
  "Condition": {
    "StringEquals": {
      "AWS:SourceArn": "<your-cloudfront-distribution-arn>"
    }
  }
}
```

</details>

<details>
<summary>Hint — Cache invalidation in GitHub Actions</summary>

```bash
aws cloudfront create-invalidation \
  --distribution-id ${{ secrets.CF_DISTRIBUTION_ID }} \
  --paths "/*"
```

</details>

---

## Submission Checklist

| Tier | Requirement | Done |
|------|-------------|------|
| 1 | App is live on S3 website URL | [ ] |
| 1 | Can post and delete notices | [ ] |
| 1 | All resources prefixed with student name | [ ] |
| 2 | GitHub Actions workflow file exists | [ ] |
| 2 | Push to main triggers auto-deploy | [ ] |
| 3 | App served over HTTPS via CloudFront | [ ] |
| 3 | S3 bucket is private (not directly accessible) | [ ] |
| 3 | Workflow invalidates CloudFront cache on deploy | [ ] |
