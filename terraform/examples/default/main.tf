# One-command apply root for PDS S3 archive.
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars   # edit values
#   terraform -chdir=terraform/examples/default init
#   terraform -chdir=terraform/examples/default apply
#   terraform -chdir=terraform/examples/default output -raw archiver_access_key_id > ~/.config/pds/aws-credentials.id
#
# The bucket_name output goes in capture.s3.bucket; the access keys go in
# ${XDG_CONFIG_HOME}/pds/aws-credentials (isolated from your user-scope ~/.aws/).

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "bucket_suffix" {
  description = "Globally-unique suffix (e.g. hash of your email). Final name: pds-<suffix>-<region>."
  type        = string
}

module "pds_s3" {
  source        = "../../pds-s3"
  bucket_name   = "pds-${var.bucket_suffix}-${var.region}"
  standard_days = 30
  tags = {
    Project = "pds"
    Owner   = "personal"
  }
}

output "bucket_name" {
  value = module.pds_s3.bucket_name
}

output "archiver_access_key_id" {
  value     = module.pds_s3.archiver_access_key_id
  sensitive = true
}

output "archiver_secret_access_key" {
  value     = module.pds_s3.archiver_secret_access_key
  sensitive = true
}
