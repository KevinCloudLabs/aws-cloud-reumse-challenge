##################################################################
# Cloud Resume — test.kevinlutes.com
# Deploys a full copy of your stack to verify everything works
# before touching your live resume.kevinlutes.com
##################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.84.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

locals {
  domain_name = "test.kevinlutes.com"
  name_prefix = "test-resume"
}

# ------------------------------------------------------------------
# DATA — look up your existing Route 53 hosted zone
# ------------------------------------------------------------------
data "aws_route53_zone" "kevinlutes" {
  name         = "kevinlutes.com"
  private_zone = false
}

# ------------------------------------------------------------------
# DYNAMODB — visitor counter table
# ------------------------------------------------------------------
resource "aws_dynamodb_table" "visitor_counter" {
  name         = "${local.name_prefix}-visitor-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = { Name = "${local.name_prefix}-visitor-counter" }
}

# Seed the starting item so Lambda doesn't error on first visit
resource "aws_dynamodb_table_item" "initial_count" {
  table_name = aws_dynamodb_table.visitor_counter.name
  hash_key   = aws_dynamodb_table.visitor_counter.hash_key

  item = jsonencode({
    id    = { S = "0" }
    views = { N = "0" }
  })

  lifecycle {
    ignore_changes = [item] # Don't reset the count on every terraform apply
  }
}

# ------------------------------------------------------------------
# IAM — role for Lambda to access DynamoDB + CloudWatch logs
# ------------------------------------------------------------------
resource "aws_iam_role" "lambda_exec" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Basic execution policy (lets Lambda write to CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Scoped DynamoDB policy — only this table
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${local.name_prefix}-dynamodb-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem"
      ]
      Resource = aws_dynamodb_table.visitor_counter.arn
    }]
  })
}

# ------------------------------------------------------------------
# LAMBDA — visitor counter function
# ------------------------------------------------------------------
resource "aws_lambda_function" "visitor_counter" {
  function_name    = "${local.name_prefix}-visitor-counter"
  filename         = "${path.module}/lambda/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/lambda.zip")
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.visitor_counter.name
    }
  }
}

# CloudWatch log group with 14 day retention
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.visitor_counter.function_name}"
  retention_in_days = 14
}

# Lambda Function URL — same approach as your live site
resource "aws_lambda_function_url" "visitor_counter" {
  function_name      = aws_lambda_function.visitor_counter.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["*"]
    max_age       = 86400
  }
}

# ------------------------------------------------------------------
# S3 — private bucket (only CloudFront can read it)
# ------------------------------------------------------------------
resource "aws_s3_bucket" "resume" {
  bucket = "${local.name_prefix}-site-${var.account_id}"
  tags   = { Name = "${local.name_prefix}-site" }
}

resource "aws_s3_bucket_public_access_block" "resume" {
  bucket                  = aws_s3_bucket.resume.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "resume" {
  bucket = aws_s3_bucket.resume.id
  versioning_configuration { status = "Enabled" }
}

# ------------------------------------------------------------------
# CLOUDFRONT — CDN + HTTPS
# ------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "resume" {
  name                              = "${local.name_prefix}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 bucket policy — only allow CloudFront to read
resource "aws_s3_bucket_policy" "resume" {
  bucket = aws_s3_bucket.resume.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontRead"
      Effect = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.resume.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.resume.arn
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.resume]
}

resource "aws_cloudfront_distribution" "resume" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [local.domain_name]
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.resume.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.resume.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = { Name = "${local.name_prefix}-distribution" }
}

# ------------------------------------------------------------------
# ROUTE 53 — point test.kevinlutes.com → CloudFront
# ------------------------------------------------------------------
resource "aws_route53_record" "resume" {
  zone_id = data.aws_route53_zone.kevinlutes.zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.resume.domain_name
    zone_id                = aws_cloudfront_distribution.resume.hosted_zone_id
    evaluate_target_health = false
  }
}

# ------------------------------------------------------------------
# LAMBDA PERMISSION — allow public invocation via Function URL
# ------------------------------------------------------------------
resource "aws_lambda_permission" "allow_public_url" {
  statement_id           = "AllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.visitor_counter.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "allow_invoke" {
  statement_id             = "FunctionURLAllowInvokeAction"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.visitor_counter.function_name
  principal                = "*"
  invoked_via_function_url = true
}
