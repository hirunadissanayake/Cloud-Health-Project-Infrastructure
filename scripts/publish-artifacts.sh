#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 ARTIFACT_BUCKET RELEASE_VERSION" >&2
  exit 64
fi

ARTIFACT_BUCKET="$1"
RELEASE_VERSION="$2"
SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIRECTORY/../.." && pwd)"

applications=(
  "backend-platform/config-server:config-server"
  "backend-platform/discovery-server:discovery-server"
  "backend-platform/api-gateway:api-gateway"
  "backend-services/patient-service:patient-service"
  "backend-services/diagnostics-service:diagnostics-service"
  "backend-services/file-service:file-service"
)

for entry in "${applications[@]}"; do
  directory="${entry%%:*}"
  application="${entry##*:}"
  echo "Building $application"
  (
    cd "$PROJECT_ROOT/$directory"
    ./mvnw clean package
  )
  gcloud storage cp \
    "$PROJECT_ROOT/$directory/target/$application-0.0.1-SNAPSHOT.jar" \
    "gs://$ARTIFACT_BUCKET/releases/$RELEASE_VERSION/$application.jar"
done

FRONTEND_ARCHIVE="$(mktemp -t cloud-health-frontend.XXXXXX.tar.gz)"
trap 'rm -f "$FRONTEND_ARCHIVE"' EXIT

echo "Packaging webapp"
tar -czf "$FRONTEND_ARCHIVE" \
  -C "$PROJECT_ROOT/frontend" \
  package.json server.mjs public
gcloud storage cp \
  "$FRONTEND_ARCHIVE" \
  "gs://$ARTIFACT_BUCKET/releases/$RELEASE_VERSION/webapp.tar.gz"

echo "Published six Java applications and the webapp to release $RELEASE_VERSION."
