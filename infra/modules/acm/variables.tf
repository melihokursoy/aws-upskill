variable "domain_name" {
  description = "Custom domain name to issue the ACM certificate for (e.g. dev.example.com)."
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
}
