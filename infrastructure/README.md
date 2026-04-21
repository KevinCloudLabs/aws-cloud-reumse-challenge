# Cloud Resume — Terraform Infrastructure

Infrastructure as Code for [resume.kevinlutes.com](https://resume.kevinlutes.com) built as part of the [Cloud Resume Challenge](https://cloudresumechallenge.dev/).

## Architecture

```
Route 53 → CloudFront → S3
                ↕
           Lambda Function URL
                ↕
            DynamoDB
```

## Stack

- **S3** — static site hosting
- **CloudFront** — CDN + HTTPS
- **Lambda** — visitor counter API (Python 3.12)
- **DynamoDB** — visitor count storage
- **Route 53** — DNS

## Setup

```powershell
cp terraform.tfvars.example terraform.tfvars
# fill in terraform.tfvars with your values

cd lambda
Compress-Archive -LiteralPath .\lambda_function.py -DestinationPath .\lambda.zip
cd ..

terraform init
terraform apply
```

## Tear Down

```powershell
terraform destroy
```
