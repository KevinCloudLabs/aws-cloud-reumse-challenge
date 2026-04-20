# Cloud Resume — Terraform IaC

Infrastructure as Code for [resume.kevinlutes.com](https://resume.kevinlutes.com) built as part of the [Cloud Resume Challenge](https://cloudresumechallenge.dev/).

Deploys a full copy of the stack to `test.kevinlutes.com` for testing before touching the live site.

## Architecture

```
Route 53 → CloudFront → S3 (static site)
                ↕
           index.js
                ↕
        Lambda Function URL
                ↕
            DynamoDB
          (visitor counter)
```

## Resources Created

| Resource | Name |
|---|---|
| S3 Bucket | `test-resume-site-{account_id}` |
| CloudFront Distribution | aliased to `test.kevinlutes.com` |
| Lambda Function | `test-resume-visitor-counter` |
| Lambda Function URL | public, no auth |
| DynamoDB Table | `test-resume-visitor-counter` |
| Route 53 A Record | `test.kevinlutes.com` → CloudFront |

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured (`aws configure`)
- Route 53 hosted zone for `kevinlutes.com`
- ACM certificate in `us-east-1` covering `*.kevinlutes.com`

## Setup

**1. Clone the repo**
```powershell
git clone https://github.com/KevinCloudLabs/cloud-resume-iac.git
cd cloud-resume-iac
```

**2. Create your tfvars file**
```powershell
cp terraform.tfvars.example terraform.tfvars
```
Then open `terraform.tfvars` and fill in your AWS account ID and ACM certificate ARN.

**3. Zip the Lambda function**
```powershell
cd lambda
Compress-Archive -LiteralPath .\lambda_function.py -DestinationPath .\lambda.zip
cd ..
```

**4. Deploy**
```powershell
terraform init
terraform apply
```

**5. Upload site files**

After apply, grab the outputs and run:
```powershell
aws s3 sync C:\path\to\your\site s3://BUCKET_NAME_FROM_OUTPUT --delete

aws cloudfront create-invalidation --distribution-id CF_ID_FROM_OUTPUT --paths "/*"
```

**6. Visit https://test.kevinlutes.com**

## Tear Down

```powershell
terraform destroy
```

Completely removes all test resources. Live site at `resume.kevinlutes.com` is unaffected.

## Redeploy

```powershell
terraform apply
# then re-upload site files and invalidate CloudFront
```
