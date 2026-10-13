#!/usr/bin/env bash
# Runs one Trivy scan the same way in CI and on a laptop.
#
# Usage: ci-trivy.sh <fs|config|image> <target> <report-name> [extra trivy flags...]
#   fs/config targets are paths INSIDE the container (the repo is mounted at /src)
#   image targets are image names
#
# Produces reports/<name>.json, .sarif and .html, then runs the gate:
# the script exits non-zero when a finding at SEVERITY (default HIGH,CRITICAL) exists.
set -euo pipefail

MODE="$1"; TARGET="$2"; NAME="$3"; shift 3

TRIVY_IMAGE="${TRIVY_IMAGE:-aquasec/trivy:0.75.0}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"

mkdir -p reports "${HOME}/.cache/trivy"

trivy() {
  docker run --rm \
    -v "${PWD}:/src" \
    -v "${HOME}/.cache/trivy:/root/.cache/trivy" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "${TRIVY_IMAGE}" "$@"
}

COMMON=(--severity "${SEVERITY}" --ignorefile /src/.trivyignore)

echo "== ${MODE} scan: report =="
trivy "${MODE}" "${COMMON[@]}" "$@" --exit-code 0 --format json --output "/src/reports/${NAME}.json" "${TARGET}"
trivy convert --format sarif --output "/src/reports/${NAME}.sarif" "/src/reports/${NAME}.json"
trivy convert --format template --template "@/contrib/html.tpl" --output "/src/reports/${NAME}.html" "/src/reports/${NAME}.json"

echo "== ${MODE} scan: gate (fails on ${SEVERITY}) =="
trivy "${MODE}" "${COMMON[@]}" "$@" --exit-code 1 "${TARGET}"
