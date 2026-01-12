terraform {
  required_version = ">= 1.3"
  required_providers {

    google = {
      source  = "hashicorp/google"
      version = ">= 6, < 7"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6, < 7"
    }
  }
}
