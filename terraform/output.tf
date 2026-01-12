output "cloud_run_service_url" {
  description = "The public URL of the Simple WebSocket Cloud Run service"
  value       = google_cloud_run_v2_service.simple_websocket_service.uri
}
