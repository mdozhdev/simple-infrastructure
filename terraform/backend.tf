terraform {
  backend "gcs" {
    bucket = "simple-websocket-service-tf-state"
    prefix = "terraform/state"
  }
}
