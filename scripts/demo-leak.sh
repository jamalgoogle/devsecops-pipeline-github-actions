#!/usr/bin/env bash
# Shows Gitleaks catching a committed secret, without touching this repository.
# It creates a throwaway git repo with fake credentials built at runtime.
set -euo pipefail

GITLEAKS_IMAGE="${GITLEAKS_IMAGE:-zricethezav/gitleaks:v8.30.1}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

cd "${WORKDIR}"
git init -q
git config user.email "demo@example.com"
git config user.name "demo"

# Fake credentials, assembled here so no secret-looking string is stored in the repository
AWS_KEY="AKIA""J5N3H7QW2XK9P4LT"
GH_TOKEN="ghp""_q7R8vL2mN4oP6s9TdW1xY3zA5bC7eF0gH2iJ"
printf 'aws_access_key_id = "%s"\ngithub_token = "%s"\n' "${AWS_KEY}" "${GH_TOKEN}" > config.txt
git add config.txt
git commit -q -m "add config"

echo ">>> Running Gitleaks against the demo repository (expected to FAIL)"
if docker run --rm -v "${WORKDIR}:/repo" "${GITLEAKS_IMAGE}" detect --source /repo --redact --verbose --exit-code 1; then
  echo "No leak detected (unexpected)"; exit 1
else
  echo ">>> Leak detected. In the pipeline this fails the secrets-scan job and blocks the merge."
fi
