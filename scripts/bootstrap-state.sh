#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 PROJECT_ID REGION STATE_BUCKET" >&2
  exit 64
fi

PROJECT_ID="$1"
REGION="$2"
STATE_BUCKET="$3"

gcloud config set project "$PROJECT_ID"
gcloud storage buckets create "gs://$STATE_BUCKET" \
  --location="$REGION" \
  --uniform-bucket-level-access \
  --public-access-prevention
gcloud storage buckets update "gs://$STATE_BUCKET" --versioning

echo "State bucket created. Copy backend.tf.example to backend.tf and set bucket to $STATE_BUCKET."
