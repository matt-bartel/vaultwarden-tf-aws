terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "remote" {
    organization = "mattb"
    workspaces {
      name = "vaultwarden-tf-aws"
    }
  }
}

provider "aws" {
  region = var.region
}
