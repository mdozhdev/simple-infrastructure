# Simple Infrastructure

A Terraform-based infrastructure provisioning repository for Google Cloud Platform (GCP).

## Overview

This infrastructure deploys a serverless WebSocket application on Google Cloud Platform using Cloud Run, with automated CI/CD deployment via GitHub Actions using Workload Identity Federation (keyless authentication).

## Prerequisites

Before you begin, ensure you have the following installed and configured:

### Required Tools

- **Terraform** (v1.3 or later)

  ```bash
  # Install via package manager or download from terraform.io
  terraform --version
  ```

- **Google Cloud SDK (gcloud CLI)**

  ```bash
  # Install from cloud.google.com/sdk/docs/install
  gcloud --version
  ```

- **Git**
  ```bash
  git --version
  ```

### Google Cloud Platform Requirements

1. **GCP Account**: Active Google Cloud Platform account
2. **GCP Project**: A GCP project with billing enabled
3. **IAM Permissions**: Appropriate permissions to create resources
   - Project Creator

     (Optional) You can use `./scripts/check_permissions.sh` to verify it. Organization and billing access wil be tested as well as temp project creation and clean up.

### Environment Variables

- **Project ID**: A globally unique identifier for your project.

  A project ID is a unique string used to differentiate your project from all others in Google Cloud. After you enter a project name, the Google Cloud console generates a unique project ID that can be a combination of letters, numbers, and hyphens. We recommend you use the generated project ID, but you can edit it during project creation. After the project has been created, the project ID is permanent.

  A project ID has the following requirements:
  - Must be 6 to 30 characters in length.
  - Can only contain lowercase letters, numbers, and hyphens.
  - Must start with a letter.
  - Cannot end with a hyphen.
  - Cannot be in use or previously used; this includes deleted projects.
  - Cannot contain restricted strings such as google and ssl. We recommend not using strings undefined and null in a project ID.

- **Project name**: A human-readable name for your project.
  The project name isn't used by any Google APIs. You can edit the project name at any time during or after project creation. Project names do not need to be unique.

- **Billing Account ID**: Required to be valid GCP billing account ID.

- **Region**: Primary GCP region to place resources to.

- **Organization ID**: Tthe unique identifier of the organization. By default `No Organization` unit will be used if no ORG_ID provided.

Set the following environment variables based on your GCP setup:

```bash
export PROJECT_ID=<YOUR_PROJECT_ID>
export PROJECT_NAME=<YOUR_PROJECT_NAME>
export BILLING_ACCOUNT_ID=<YOUR_BILLING_ACCOUNT_ID>
export REGION=<YOUR_PREFERRED_REGION>  # e.g., us-central1, europe-west1
```

(Optional) Set Organization ID:

```bash
export ORG_ID=<YOUR_ORGANIZATION_ID>
```

## Authentication

### Initial Setup

1. **Authenticate with Google Cloud**:

   ```bash
   gcloud auth login
   ```

   This opens a browser window for interactive authentication.

2. **Set Application Default Credentials**:

   ```bash
   gcloud auth application-default login
   ```

   This allows Terraform to authenticate using your user credentials.

3. **Set the Active Account**:

   ```bash
   gcloud config set account <YOUR_EMAIL>
   ```

## Project bootstraping

Create GCP project from scratch:

```bash
./scripts/check_permission.sh
```

This will create:

- GCP project
- Enable GCP APIs requred to deploy service
- Cloud Storage bucket to keep Terraform state available for team work
- Terraform service account with required IAM roles:

Please verify that `./terraform/default.auto.tf` file is present and populated with Project, Region, Account information.

Update `./terraform/default.auto.tf` with information about Service Github organization and repo and OpenAI API KEY.

## Usage

### Initialize Terraform

Navigate to the terraform directory and initialize:

```bash
cd terraform
terraform init
```

This downloads the required provider plugins and sets up the backend.

### Plan Infrastructure Changes

Review the changes Terraform will make:

```bash
terraform plan
```

To save the plan for later application:

```bash
terraform plan -out=tfplan
```

### Apply Infrastructure Changes

Deploy the infrastructure:

```bash
terraform apply
```

Or apply a saved plan:

```bash
terraform apply tfplan
```

Type `yes` when prompted to confirm the changes.

### Destroy Infrastructure

To tear down all resources:

```bash
terraform destroy
```

Type `yes` when prompted to confirm destruction.

### View Outputs

After applying, view the output values:

```bash
terraform output
```

## State Management

Currently Remote State is used.
Configured in `backend.tf`:

```hcl
terraform {
  backend "gcs" {
    bucket = "simple-websocket-service-tf-state"
    prefix = "terraform/state"
  }
}
```

Bucket itself was created during Project bootstraping and is not managed by Terraform.

## Variables Configuration

### Using terraform.tfvars

Create a `terraform.tfvars` file in the terraform directory:

```hcl
project_id = "your-project-id"
region     = "us-central1"
zone       = "us-central1-a"
environment = "dev"
```

### Using Environment Variables

Alternatively, set variables via environment:

```bash
export TF_VAR_project_id="your-project-id"
export TF_VAR_region="us-central1"
```

### Using Command Line

Pass variables directly:

```bash
terraform apply -var="project_id=your-project-id" -var="region=us-central1"
```

## Common Issues and Troubleshooting

### Project Creation Permissions

If you encounter permission errors when creating projects:

1. Ensure you have the `resourcemanager.projects.create` permission
2. Verify your organization ID is correct
3. Check that you're authenticated with the correct account
4. Ensure billing is linked to the project

### API Not Enabled

If you see "API not enabled" errors:

```bash
# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
```

### State Lock Issues

If Terraform state is locked:

```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Authentication Issues

If facing authentication problems:

```bash
# Clear existing credentials
gcloud auth revoke

# Re-authenticate
gcloud auth login
gcloud auth application-default login
```

## Best Practices

1. **Version Control**: Always commit your Terraform code to version control
2. **State Files**: Never commit `terraform.tfstate` files; use remote backends
3. **Variables**: Use `terraform.tfvars` for environment-specific values
4. **Modules**: Organize reusable infrastructure into Terraform modules
5. **Secrets**: Use Google Secret Manager or environment variables for sensitive data
6. **Plan Before Apply**: Always run `terraform plan` before `terraform apply`
7. **Resource Naming**: Use consistent naming conventions with environment prefixes
8. **Tags/Labels**: Apply labels to all resources for better organization and cost tracking

## Security Considerations

- Use service accounts with minimal required permissions
- Enable audit logging for all infrastructure changes
- Store state files in encrypted GCS buckets with versioning
- Rotate service account keys regularly
- Use VPC Service Controls for sensitive workloads
- Implement network security policies and firewall rules

### Code Standards

- Format code with `terraform fmt`
- Validate syntax with `terraform validate`
- Document variables and outputs with descriptions
- Follow the [Google Cloud best practices](https://cloud.google.com/docs/terraform/best-practices-for-terraform)

# What's next

## Possible infrastructure improvements

- Harden Secret Manager Configuration
  Add rotation and replication policies:

  ```hcl
    secrets = [
    {
      name        = "openai_api_key"
      secret_data = var.openai_api_key

      # Add automatic rotation reminder
      rotation = {
        rotation_period = "2592000s"  # 30 days
      }

      # Add replication for HA
      replication = {
        automatic = true
      }
    },
  ]
  ```

- Add Audit Logging.

  Enable data access audit logs for security:

  ```hcl
  resource "google_project_iam_audit_config" "audit" {
    project = var.project_id
    service = "allServices"

    audit_log_config {
      log_type = "ADMIN_READ"
    }

    audit_log_config {
      log_type = "DATA_READ"
    }

    audit_log_config {
      log_type = "DATA_WRITE"
    }
  }
  ```

- Add Monitoring and Alerting

  ```hcl
  # Add monitoring notification channel
  resource "google_monitoring_notification_channel" "email" {
    display_name = "Email Notification Channel"
    type         = "email"

    labels = {
      email_address = var.alert_email
    }
  }

  # Alert on Cloud Run errors
  resource "google_monitoring_alert_policy" "cloud_run_errors" {
    display_name = "Cloud Run Error Rate"
    combiner     = "OR"

    conditions {
      display_name = "Error rate above threshold"

      condition_threshold {
        filter          = <<-EOT
          resource.type = "cloud_run_revision"
          AND resource.labels.service_name = "${var.service_name}"
          AND metric.type = "run.googleapis.com/request_count"
          AND metric.labels.response_code_class = "5xx"
        EOT
        duration        = "60s"
        comparison      = "COMPARISON_GT"
        threshold_value = 5

        aggregations {
          alignment_period   = "60s"
          per_series_aligner = "ALIGN_RATE"
        }
      }
    }

    notification_channels = [
      google_monitoring_notification_channel.email.id
    ]
  }
  ```

- Add GCS Bucket Security and reduce storage costs

  ```hcl
  resource "google_storage_bucket" "audio_files" {
    name          = "${var.project_id}-audio-files"
    location      = var.region
    storage_class = "STANDARD"

    uniform_bucket_level_access = true

    versioning {
      enabled = false
    }

    lifecycle_rule {
      condition {
        age = 365
      }
      action {
        type = "Delete"
      }
    }

    # Add lifecycle rule for cost optimization
    lifecycle_rule {
      condition {
        age = 90  # Move to cheaper storage after 90 days
      }
      action {
        type          = "SetStorageClass"
        storage_class = "NEARLINE"
      }
    }
  }
  ```

- Publish audio files as static content (for debug)

  ```hcl
  resource "google_storage_bucket" "audio_files" {
    name          = "${var.project_id}-audio-files"
    location      = var.region
    storage_class = "STANDARD"

    uniform_bucket_level_access = true

    # Add CORS if accessed from browser
    cors {
      origin          = ["*"]  # Restrict to your domain
      method          = ["GET", "HEAD"]
      response_header = ["*"]
      max_age_seconds = 3600
    }

    # Enable logging
    logging {
      log_bucket = google_storage_bucket.logs.name
    }
  }

  # Bucket for storing access logs
  resource "google_storage_bucket" "logs" {
    name          = "${var.project_id}-logs"
    location      = var.region
    storage_class = "STANDARD"

    uniform_bucket_level_access = true
    force_destroy              = true

    lifecycle_rule {
      condition {
        age = 30
      }
      action {
        type = "Delete"
      }
    }
  }
  ```

- Add Terraform Validation in CI

  Add to your GitHub Actions workflow:

  ```yaml
  - name: Terraform Format Check
    run: terraform fmt -check -recursive

  - name: Terraform Validate
    run: terraform validate

  - name: TFLint
    uses: terraform-linters/setup-tflint@v3
    with:
    tflint_version: latest
  ```

- Split into Modules

  main.tf is getting large. Consider this structure:

  ```
  terraform/
  ├── main.tf                    # Orchestration only
  ├── variables.tf
  ├── outputs.tf
  ├── providers.tf
  ├── backend.tf
  ├── modules/
  │   ├── service-accounts/
  │   │   ├── main.tf
  │   │   ├── variables.tf
  │   │   └── outputs.tf
  │   ├── github-oidc/
  │   │   ├── main.tf
  │   │   ├── variables.tf
  │   │   └── outputs.tf
  │   ├── cloud-run-service/
  │   │   ├── main.tf
  │   │   ├── variables.tf
  │   │   └── outputs.tf
  │   └── storage/
  │       ├── main.tf
  │       ├── variables.tf
  │       └── outputs.tf
  ```

- Use Terraform workspaces to separate Dev/Stage/Prod infrastructure.

  Separate common and ENV's specific configuration and create structure like:

  ```
  terraform/
  ├── modules/                     # Reusable modules
  │   ├── service-accounts/
  │   │   ├── main.tf
  │   │   ├── variables.tf
  │   │   └── outputs.tf
  │   │
  │   ├── github-oidc/
  │   │   ├── main.tf
  │   │   ├── variables.tf
  │   │   └── outputs.tf
  │   │
  │   ├── cloud-run/
  │   │   ├── main.tf
  │   │   ├── variables.tf
  │   │   └── outputs.tf
  │   │
  │   ├── storage/
  │   │   ├── main.tf
  │   │   ├── variables.tf
  │   │   └── outputs.tf
  │   │
  │   └── networking/              # Optional VPC module
  │       ├── main.tf
  │       ├── variables.tf
  │       └── outputs.tf
  │
  ├── environments/                # Environment-specific configs
  │   ├── dev.tfvars
  │   ├── stage.tfvars
  │   └── prod.tfvars
  │
  ├── main.tf                      # Main orchestration
  ├── variables.tf                 # Variable definitions
  ├── outputs.tf                   # Output definitions
  ├── providers.tf                 # Provider configuration
  ├── backend.tf                   # Backend configuration
  ├── locals.tf                    # Local values and logic
  ├── data.tf                      # Data sources
  ├── versions.tf                  # Terraform version constraints
  ├── service-accounts.tf          # Service account resources
  ├── iam.tf                       # IAM bindings
  ├── github-oidc.tf              # GitHub OIDC configuration
  ├── artifact-registry.tf        # Docker repository
  ├── secrets.tf                  # Secret Manager
  ├── storage.tf                  # GCS buckets
  ├── cloud-run.tf                # Cloud Run service
  ├── monitoring.tf               # Monitoring and alerts
  └── networking.tf               # VPC and network (optional)
  ```

## Get it ready to Production considerations

- Add External Load Balancer and Domain Mapping following [official guide](https://docs.cloud.google.com/run/docs/mapping-custom-domains)

- Update min_instance_count and autoscaling settions to keep some instances always ready to serve traffic.

- Specify max_instance_count for Cloud Run Service to prevent runaway costs

- Add Budgets and Billing Alerts

- Add cost optimization with committed use discounts

- Implement backup and disaster recovery

- Implement VPC, Firewall Rules, Egress Control, Flow Logs

- Implement Cloud Armor for DDoS Protection
