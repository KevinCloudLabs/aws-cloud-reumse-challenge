output "site_url" {
  description = "Your test site — open this to verify everything works"
  value       = "https://test.kevinlutes.com"
}

output "lambda_function_url" {
  description = "Paste this into index.js before uploading your frontend files"
  value       = aws_lambda_function_url.visitor_counter.function_url
}

output "s3_bucket_name" {
  description = "Upload your frontend files to this bucket"
  value       = aws_s3_bucket.resume.id
}

output "cloudfront_distribution_id" {
  description = "Use this to invalidate the CloudFront cache after uploading files"
  value       = aws_cloudfront_distribution.resume.id
}
