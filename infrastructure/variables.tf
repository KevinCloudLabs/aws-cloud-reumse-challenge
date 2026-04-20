variable "account_id" {
  description = "Your AWS account ID — keeps the S3 bucket name globally unique. Find it with: aws sts get-caller-identity --query Account --output text"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of your *.kevinlutes.com certificate — must be in us-east-1. Find it with: aws acm list-certificates --region us-east-1"
  type        = string
}
