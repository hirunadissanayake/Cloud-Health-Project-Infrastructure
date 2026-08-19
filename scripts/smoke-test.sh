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

TEST_PATIENT_ID="00000000-0000-0000-0000-000000000000"

echo "Checking the diagnostics route and MongoDB connectivity"
curl --fail --silent --show-error \
  "$API_URL/api/records?patientId=$TEST_PATIENT_ID&size=1" | jq -e '.content | type == "array"'

echo "Checking the file route and Firestore connectivity"
curl --fail --silent --show-error \
  "$API_URL/api/files?patientId=$TEST_PATIENT_ID&limit=1" | jq -e 'type == "array"'

echo "External smoke test passed."
