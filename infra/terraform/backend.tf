terraform {
  backend "gcs" {
    bucket = "paragjo-gitops-tfstate"
    prefix = "gitops-incident-simulation/terraform"
  }
}
