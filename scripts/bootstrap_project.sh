#!/usr/bin/env bash
set -euo pipefail

############################
# USER CONFIG
############################

PROJECT_ID=${PROJECT_ID:-"my-gcp-tf-project-001"}
PROJECT_NAME=${PROJECT_NAME:-"Terraform Managed Project"}
ORG_ID=${ORG_ID:-"0"}
BILLING_ACCOUNT_ID=${BILLING_ACCOUNT_ID:-"AAAAAA-BBBBBB-CCCCCC"}

REGION=${REGION:-"europe-west1"}

TF_STATE_BUCKET="${PROJECT_ID}-tf-state"
TF_SA_NAME="terraform-sa"
TF_SA_DISPLAY_NAME="Terraform Service Account"

TF_DIR="../terraform"

############################
# DERIVED VALUES
############################

TF_SA_EMAIL="${TF_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

############################
# CREATE PROJECT
############################

PROJECT_PARENT_ARGS=()

if [[ "${ORG_ID}" != "0" ]]; then
  echo "Using organization: ${ORG_ID}"
  PROJECT_PARENT_ARGS+=(--organization="${ORG_ID}")
else
  echo "No organization will be used for project creation."
fi

echo "Creating project..."
gcloud projects create "${PROJECT_ID}" \
  --name="${PROJECT_NAME}" \
  "${PROJECT_PARENT_ARGS[@]}"

echo "Linking billing account..."
gcloud billing projects link "${PROJECT_ID}" \
  --billing-account="${BILLING_ACCOUNT_ID}"

gcloud config set project "${PROJECT_ID}"

############################
# ENABLE APIS
############################

echo "Enabling APIs..."
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  serviceusage.googleapis.com \
  compute.googleapis.com \
  storage.googleapis.com

############################
# CREATE TF STATE BUCKET
############################

echo "Creating Terraform state bucket..."
gsutil mb \
  -p "${PROJECT_ID}" \
  -l "${REGION}" \
  -b on \
  "gs://${TF_STATE_BUCKET}"

echo "Enabling bucket versioning..."
gsutil versioning set on "gs://${TF_STATE_BUCKET}"

############################
# CREATE TERRAFORM SERVICE ACCOUNT
############################

echo "Creating Terraform service account..."
gcloud iam service-accounts create "${TF_SA_NAME}" \
  --display-name="${TF_SA_DISPLAY_NAME}"

############################
# IAM ROLES FOR TERRAFORM
############################

echo "Granting IAM roles..."

ROLES=(
  roles/editor
  roles/iam.serviceAccountAdmin
  roles/resourcemanager.projectIamAdmin
  roles/iam.securityAdmin
  roles/iam.workloadIdentityPoolAdmin
  roles/serviceusage.serviceUsageAdmin
  roles/storage.admin
)

for ROLE in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${TF_SA_EMAIL}" \
    --role="${ROLE}"
done

############################
# SERVICE ACCOUNT KEY (OPTIONAL)
############################

echo "Creating service account key..."
mkdir -p .secrets

gcloud iam service-accounts keys create \
  ".secrets/terraform-sa-key.json" \
  --iam-account="${TF_SA_EMAIL}"

############################
# CREATE default.tfvars
############################

echo "Creating default.tfvars..."

mkdir -p "${TF_DIR}"

cat > "${TF_DIR}/default.auto.tfvars" <<EOF
project_id           = "${PROJECT_ID}"
region               = "${REGION}"
tf_state_bucket_name = "${TF_STATE_BUCKET}"
tf_service_account   = "${TF_SA_EMAIL}"
github_org           = "github-org"
github_repo          = "simple-websocket-service"
openai_api_key       = "sk-proj-XXXX"
EOF

############################
# FINAL OUTPUT
############################

echo ""
echo "Bootstrap completed successfully!"
echo ""
echo "Next steps:"
echo "  export GOOGLE_APPLICATION_CREDENTIALS=\"$(pwd)/.secrets/terraform-sa-key.json\""
echo "  cd terraform"
echo "  terraform init"
echo "  terraform plan"
