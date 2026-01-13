output "cloud_run_service_url" {
  description = "The public URL of the Simple WebSocket Cloud Run service"
  value       = google_cloud_run_v2_service.simple_websocket_service.uri
}

output "docker_repository_url" {
  description = "Docker repository URL for pushing images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.docker_repository_id}"
}

output "github_deployer_email" {
  description = "Email of the GitHub deployer service account"
  value       = google_service_account.service_accounts["github_deployer"].email
}

output "workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "audio_bucket_name" {
  description = "Name of the GCS bucket for audio files"
  value       = google_storage_bucket.audio_files.name
}
