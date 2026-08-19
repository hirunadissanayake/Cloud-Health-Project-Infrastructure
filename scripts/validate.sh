#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
INFRASTRUCTURE_DIRECTORY="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"

bash -n "$SCRIPT_DIRECTORY/bootstrap-state.sh"
bash -n "$SCRIPT_DIRECTORY/publish-artifacts.sh"
bash -n "$SCRIPT_DIRECTORY/smoke-test.sh"
bash -n "$INFRASTRUCTURE_DIRECTORY/templates/startup.sh.tftpl"
bash -n "$INFRASTRUCTURE_DIRECTORY/images/provision-image.sh"

if command -v terraform >/dev/null 2>&1; then
  terraform -chdir="$INFRASTRUCTURE_DIRECTORY" fmt -check -recursive
  terraform -chdir="$INFRASTRUCTURE_DIRECTORY" validate
else
  echo "Terraform is not installed; shell/template syntax passed, HCL validation skipped." >&2
fi

if command -v packer >/dev/null 2>&1; then
  packer fmt -check "$INFRASTRUCTURE_DIRECTORY/images/cloud-health.pkr.hcl"
  packer validate -syntax-only "$INFRASTRUCTURE_DIRECTORY/images/cloud-health.pkr.hcl"
fi
