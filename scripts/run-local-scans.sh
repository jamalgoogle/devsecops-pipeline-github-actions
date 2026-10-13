#!/usr/bin/env bash
# Runs the same scanners as the CI pipeline on your machine (needs Docker).
#   ./scripts/run-local-scans.sh            # secrets, dependencies, IaC
#   ./scripts/run-local-scans.sh image      # build the image and scan it
#   ./scripts/run-local-scans.sh examples   # scan the intentionally insecure Terraform (expected to FAIL)
set -euo pipefail

export TRIVY_IMAGE="${TRIVY_IMAGE:-aquasec/trivy:0.75.0}"
GITLEAKS_IMAGE="${GITLEAKS_IMAGE:-zricethezav/gitleaks:v8.30.1}"
STAGE="${1:-all}"

secrets() {
  echo ">>> Gitleaks"
  mkdir -p reports
  docker run --rm --user "$(id -u):$(id -g)" -v "${PWD}:/repo" "${GITLEAKS_IMAGE}" detect \
    --source /repo --config /repo/.gitleaks.toml \
    --report-format sarif --report-path /repo/reports/gitleaks.sarif --redact --verbose --exit-code 1
}

deps() {
  echo ">>> Dependencies (npm audit + Trivy)"
  (cd app && npm audit --omit=dev --audit-level=high)
  ./scripts/ci-trivy.sh fs /src/app trivy-dependencies --scanners vuln --ignore-unfixed
}

iac() {
  echo ">>> Terraform and Dockerfile (Trivy config)"
  ./scripts/ci-trivy.sh config /src iac-scan --skip-dirs examples --skip-dirs "**/node_modules"
}

image() {
  echo ">>> Container image (Trivy)"
  docker build -t novacart-payments-api:local app
  ./scripts/ci-trivy.sh image novacart-payments-api:local trivy-image --ignore-unfixed --scanners vuln,secret
}

examples() {
  echo ">>> Insecure Terraform demo (this is expected to fail)"
  ./scripts/ci-trivy.sh config /src/examples/insecure-terraform examples-demo
}

case "${STAGE}" in
  all)      secrets; deps; iac ;;
  secrets)  secrets ;;
  deps)     deps ;;
  iac)      iac ;;
  image)    image ;;
  examples) examples ;;
  *) echo "Unknown stage: ${STAGE}"; exit 2 ;;
esac
