terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Remote state — supply bucket/table/key/region via -backend-config at init.
  backend "s3" {
    encrypt = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}
