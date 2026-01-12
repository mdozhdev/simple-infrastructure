############################
# PREFLIGHT CHECKS
############################

echo "Running pre-flight permission checks..."

ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null)

if [[ -z "$ACTIVE_ACCOUNT" ]]; then
  echo "ERROR: No active gcloud account found."
  echo "Run: gcloud auth login"
  exit 1
fi

echo "Active gcloud account: $ACTIVE_ACCOUNT"

############################
# ORG ACCESS CHECK
############################

if [[ "${ORG_ID}" != "0" ]]; then
  echo "Checking organization access..."

  if ! gcloud organizations describe "${ORG_ID}" >/dev/null 2>&1; then
    echo "ERROR: Cannot access organization ${ORG_ID}"
    echo "Ensure you have access to the organization and correct ORG_ID."
    exit 1
  fi
else
  echo "Skip checking organization access..."
fi

############################
# PROJECT CREATION CHECK
############################

echo "Checking project creation permission..."

TMP_PROJECT_ID="permission-check-$(date +%s)"

PROJECT_PARENT_ARGS=()

if [[ "${ORG_ID}" != "0" ]]; then
  echo "Using organization: ${ORG_ID}"
  PROJECT_PARENT_ARGS+=(--organization="${ORG_ID}")
else
  echo "No organization will be used for project creation."
fi

set +e
PROJECT_CREATE_OUTPUT=$(gcloud projects create "${TMP_PROJECT_ID}" \
  "${PROJECT_PARENT_ARGS[@]}" \
  --quiet 2>&1)
CREATE_EXIT_CODE=$?
set -e

if [[ $CREATE_EXIT_CODE -ne 0 ]]; then
  if echo "$PROJECT_CREATE_OUTPUT" | grep -q "resourcemanager.projects.create"; then
    echo "ERROR: Missing permission: resourcemanager.projects.create"
    echo "You likely need role:"
    echo "  roles/resourcemanager.projectCreator"
    echo "on the organization or folder."
  else
    echo "ERROR: Project creation test failed:"
    echo "$PROJECT_CREATE_OUTPUT"
  fi
  exit 1
fi

echo "Project creation permission OK."

# Cleanup temp project
echo "Cleaning up permission test project..."
gcloud projects delete "${TMP_PROJECT_ID}" --quiet

############################
# BILLING ACCESS CHECK
############################

echo "Checking billing account access..."

if ! gcloud billing accounts describe "${BILLING_ACCOUNT_ID}" >/dev/null 2>&1; then
  echo "ERROR: Cannot access billing account ${BILLING_ACCOUNT_ID}"
  echo "Ensure you have roles/billing.user on the billing account."
  exit 1
fi

echo "Billing access OK."
