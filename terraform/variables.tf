variable "org_id" {
  type        = string
  description = "Default GCP organization"
  default     = "0"
}

variable "project_id" {
  type        = string
  description = "Default GCP project"
}

variable "region" {
  type        = string
  description = "Default GCP region"
}

variable "tf_state_bucket_name" {
  type        = string
  description = "TF state bucken name"
}

variable "tf_service_account" {
  type        = string
  description = "Default Service account to impersonate"
}

variable "docker_repository_id" {
  type        = string
  description = "GAR Docker repo id"
  default     = "docker"
}

variable "openai_api_key" {
  type        = string
  description = "OpenAI API Key"
  sensitive   = true
}

variable "service_name" {
  type    = string
  default = "simple-websocket-service"
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user name"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
  default     = "simple-websocket-service"
}
