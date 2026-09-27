terraform {
  required_version = ">= 1.16.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = "project-811ca46f-289b-42fd-9b9"
  region  = "asia-south1"
  zone    = "asia-south1-a"
}
