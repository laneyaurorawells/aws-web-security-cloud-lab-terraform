variable "target_app" {
  description = "Which Vulnerable target application to deploy: juice_shop, mutillidae, vuln_bank, or altoroj"
  type        = string
  default     = "juice_shop"

  validation {
    condition     = contains(["dvwa", "webgoat", "bwapp", "juice_shop", "mutillidae", "vuln_bank", "altoroj"], var.target_app)
    error_message = "target_app must be one of \"juice_shop\", \"mutillidae\", \"vuln_bank\", \"altoroj\", \"dvwa\", \"webgoat\", \"bwapp\""
  }
}