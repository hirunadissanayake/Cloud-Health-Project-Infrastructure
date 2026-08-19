#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 API_URL" >&2
  exit 64
fi

API_URL="${1%/}"

echo "Checking API Gateway through the global load balancer"
curl --fail --silent --show-error "$API_URL/actuator/health" | jq -e '.status == "UP"'

echo "Checking the patient route and Cloud SQL connectivity"
curl --fail --silent --show-error "$API_URL/api/patients?size=1" | jq -e '.content | type == "array"'

echo "Checking expected gateway routes"
curl --fail --silent --show-error "$API_URL/actuator/gateway/routes" \
  | jq -e 'map(.route_id) | index("patient-service-patients") != null and index("diagnostics-service") != null and index("file-service") != null'

echo "External smoke test passed."
