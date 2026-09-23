output "deployed_target_app" {
  value = var.target_app
}

output "app_url" {
  description = "Convenience URL for the app that was deployed (accounts for apps not served at root, e.g.AltoroJ)"
  value       = "https://${aws_cloudfront_distribution.js_cdn.domain_name}${local.selected_app.health_check_path}"
}
