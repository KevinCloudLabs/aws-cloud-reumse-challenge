output "site_url" {
  value = "https://test.kevinlutes.com"
}

output "lambda_function_url" {
  value = aws_lambda_function_url.visitor_counter.function_url
}

output "s3_bucket_name" {
  value = aws_s3_bucket.resume.id
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.resume.id
}
