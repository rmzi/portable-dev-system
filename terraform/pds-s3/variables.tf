variable "bucket_name" {
  description = "Globally-unique bucket name. Suggested pattern: pds-<hash>-<region>."
  type        = string
  validation {
    condition     = length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63
    error_message = "Bucket names must be 3–63 characters."
  }
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "standard_days" {
  description = "Days in S3 Standard before transition to Deep Archive."
  type        = number
  default     = 30
  validation {
    condition     = var.standard_days >= 1
    error_message = "standard_days must be at least 1."
  }
}
