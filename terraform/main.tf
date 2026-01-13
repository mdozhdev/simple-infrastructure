locals {
  service_accounts = {
    github_deployer = {
      account_id   = "github-deployer"            # Service account used by GitHub Actions to deploy infrastructure and services
      display_name = "GitHub Actions Deployer SA" # Service account used by the Cloud Run WebSocket service at runtime
    }

    simple_websocket_service = {
      account_id   = "simple-websocket-service"
      display_name = "Simple WebSocket service SA"
    }
  }

  project_iam_roles = {
    github_deployer = [
      "roles/iam.serviceAccountUser", # Allows the GitHub deployer SA to impersonate other service accounts
      "roles/run.developer",          # Allows the GitHub deployer service account to manage the Cloud Run service
    ],
    simple_websocket_service = []
  }

  service_account_iam_roles = {
    github_deployer = [
      {
        role   = "roles/iam.workloadIdentityUser" # Grants GitHub Actions permission to impersonate the deployer service account
        member = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/attribute.repository/${var.github_org}/${var.github_repo}"
      }
    ]
  }

  project_iam_bindings = flatten([
    for sa_key, roles in local.project_iam_roles : [
      for role in roles : {
        sa_key = sa_key
        role   = role
      }
    ]
  ])

  # List of enabled Google Cloud Platfor service APIs in project"
  enabled_gcp_services = [
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ]
}

# Enables required GCP APIs for the project
resource "google_project_service" "project_services" {
  for_each = {
    for name in toset(local.enabled_gcp_services) : name => name
  }
  project = var.project_id
  service = each.value
}

resource "google_service_account" "service_accounts" {
  for_each = local.service_accounts

  project      = var.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
}

resource "google_project_iam_member" "project_iam" {
  for_each = {
    for b in local.project_iam_bindings :
    "${b.sa_key}-${b.role}" => b
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.service_accounts[each.value.sa_key].email}"
}

resource "google_service_account_iam_member" "service_account_iam" {
  for_each = {
    for sa_key, bindings in local.service_account_iam_roles :
    sa_key => bindings
  }

  service_account_id = google_service_account.service_accounts[each.key].name
  role               = each.value[0].role
  member             = each.value[0].member
}

# Workload Identity Pool for GitHub Actions OIDC authentication
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions Pool"
  description               = "Pool to allow GitHub Actions to impersonate a service account"
  disabled                  = false
}

# OIDC provider that trusts GitHub Actions tokens
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions Provider"
  description                        = "OIDC provider for GitHub Actions"

  # Restricts access to a specific GitHub repository
  attribute_condition = "attribute.repository == \"${var.github_org}/${var.github_repo}\""

  # Maps GitHub OIDC claims to Google IAM attributes
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.aud"        = "assertion.aud"
    "attribute.repository" = "assertion.repository"
  }

  # GitHub Actions OIDC issuer
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Creates an Artifact Registry Docker repository with read/write access controls
module "docker_repository" {
  source  = "GoogleCloudPlatform/artifact-registry/google"
  version = "~> 0.8.2"

  project_id    = var.project_id
  location      = var.region
  format        = "DOCKER"
  repository_id = var.docker_repository_id

  # Runtime SA can read images; GitHub deployer can push images
  members = {
    readers = [
      "serviceAccount:${google_service_account.service_accounts["simple_websocket_service"].email}",
    ],
    writers = [
      "serviceAccount:${google_service_account.service_accounts["github_deployer"].email}",
    ]
  }

  depends_on = [
    google_project_service.project_services["artifactregistry.googleapis.com"]
  ]
}

# Stores the OpenAI API key securely in Secret Manager
module "openai_api_key" {
  source  = "GoogleCloudPlatform/secret-manager/google"
  version = "~> 0.9"

  project_id = var.project_id

  secrets = [
    {
      name        = "openai_api_key"
      secret_data = var.openai_api_key
    },
  ]

  # Grants the Cloud Run service access to the secret
  secret_accessors_list = [
    "serviceAccount:${google_service_account.service_accounts["simple_websocket_service"].email}",
  ]

  depends_on = [
    google_project_service.project_services["secretmanager.googleapis.com"]
  ]
}

# GCS bucket for storing generated audio files
resource "google_storage_bucket" "audio_files" {
  name          = "${var.project_id}-audio-files"
  location      = var.region
  storage_class = "STANDARD"

  # Enforces uniform IAM access at the bucket level
  uniform_bucket_level_access = true

  # Disables object versioning
  versioning {
    enabled = false
  }

  # Automatically deletes audio files older than 1 year
  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }
}

# Grants the Cloud Run service full read/write access to audio files in GCS
resource "google_storage_bucket_iam_member" "audio_files_rw" {
  bucket = google_storage_bucket.audio_files.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.service_accounts["simple_websocket_service"].email}"
}

# Deploys the WebSocket backend as a Cloud Run (Gen 2) service
resource "google_cloud_run_v2_service" "simple_websocket_service" {
  name     = var.service_name
  location = var.region

  template {
    # Runs the service using the dedicated runtime service account
    service_account = google_service_account.service_accounts["simple_websocket_service"].email

    containers {
      # Docker image built and pushed by GitHub Actions
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.docker_repository_id}/${var.service_name}:latest"

      # Injects OpenAI API key from Secret Manager
      env {
        name = "OPENAI_API_KEY"
        value_source {
          secret_key_ref {
            secret  = "openai_api_key"
            version = "latest"
          }
        }
      }

      # Exposes the HTTP port used by the WebSocket server
      ports {
        name           = "http1"
        container_port = 8000
      }

      # Mounts the GCS bucket into the container filesystem
      volume_mounts {
        name       = "audio_files"
        mount_path = "/app/audio_files"
      }
    }

    # Connects the container volume to the GCS bucket
    volumes {
      name = "audio_files"
      gcs {
        bucket    = google_storage_bucket.audio_files.name
        read_only = false
      }
    }
  }

  # Allows Cloud Run to scale down to zero instances
  scaling {
    min_instance_count    = 0
    manual_instance_count = 0
  }

  depends_on = [
    module.docker_repository,
    module.openai_api_key,
    google_storage_bucket.audio_files,
    google_project_service.project_services["run.googleapis.com"],
  ]

  lifecycle {
    ignore_changes = [
      client_version,
      client,
      template[0].containers[0].image, # Prevents Terraform from overwriting image updates made by CI/CD
    ]
  }
}
