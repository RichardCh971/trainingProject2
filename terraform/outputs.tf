output "website_url" {
  value = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "api_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

output "lambda_name" {
  value = aws_lambda_function.backend.function_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}