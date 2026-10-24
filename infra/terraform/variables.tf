variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
  default     = "project-811ca46f-289b-42fd-9b9"
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "Google Cloud zone"
  type        = string
  default     = "asia-south1-a"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "gitops-gke"
}
