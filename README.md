# Infrastructure

Terraform and Packer configuration for the production-style deployment required by the ITS 2130 project. Running `terraform apply` creates billable Google Cloud resources; validation commands do not.

## About

This repository is part of the Cloud Health Project for ITS 2130 Enterprise Cloud Architecture. It provisions the private network, managed data services, scalable backend compute, public entry point, frontend container repository, secrets, and deployment identities required by the system.

## Tech Stack

| Technology | Details |
|---|---|
| Terraform | Reproducible Google Cloud resources |
| Packer | Optional Java 25 golden VM image |
| Google Cloud VPC | Private networking and firewall controls |
| Regional MIG | Multi-zone application compute and autoscaling |
| Cloud SQL | Highly available PostgreSQL 17 |
| Cloud Storage / Firestore | Medical objects, artifacts, and metadata |
| Secret Manager | MongoDB connection URI and database credentials |
| Cloud Load Balancing | Separate API, platform, and webapp entry points |
| Workload Identity Federation | Keyless GitHub Actions authentication |

## Infrastructure Details

| Property | Value |
|---|---|
| Repository | `Cloud-Health-Project-Infrastructure` |
| GCP project | `cloud-health-506015-hiruna` |
| Default region | `asia-south1` |
| Default zones | `asia-south1-a`, `asia-south1-b` |

## Architecture

```text
Users
  |--- lb-webapp --------------------> webapp :3000
  |--- lb-api-gateway ---------------> API Gateway :8080
  |--- lb-platform-configserver -----> Config Server :8888 / Eureka :8761
                                      |
Regional managed instance group (2+ private VMs across zones)
  each VM: Config + Eureka + Gateway + 3 services + webapp + health monitors
           |
     private VPC / Cloud NAT
       |          |          |             |
  Cloud SQL   MongoDB URI  Firestore   Cloud Storage
  PostgreSQL  Secret/Atlas  metadata   files + artifacts
```

The three external Application Load Balancers use separate backend services and health checks while sharing the same regional MIG. Autohealing uses port `8090`. The local health monitor only returns `200` when all six Spring processes, the webapp, and the platform proxy report readiness.

## Resources

- Custom-mode VPC, regional private subnet, flow logs, Private Google Access
- Cloud Router and Cloud NAT with a reserved egress IP; application VMs receive no external IPs
- Firewall access only from Google load-balancer proxy/health ranges and IAP SSH
- Private-service networking allocation for Cloud SQL
- Regional PostgreSQL 17 with HA, SSD, automated backups, PITR, query insights, and deletion protection
- Firestore Native mode with PITR and deletion protection
- Private, uniform-access, public-access-prevented artifact and medical-file buckets
- Runtime service account with resource-scoped bucket and Secret Manager permissions
- Regional MIG across at least two zones, proactive rolling replacement, autohealing, and CPU autoscaling
- Three global external Application Load Balancers named `lb-api-gateway`, `lb-platform-configserver`, and `lb-webapp`
- Optional GitHub Actions Workload Identity Federation restricted to one repository and the `main` branch
- Artifact Registry repository for optional Cloud Run builds and a versioned webapp artifact for the MIG

MongoDB itself is expected to be an authenticated managed deployment such as MongoDB Atlas. Terraform stores its URI in Secret Manager and the VM startup script retrieves it through the metadata-server identity. No service-account key is created.

## Getting Started

### Prerequisites

- A Google Cloud project with billing enabled
- Terraform 1.8 or newer and Google Cloud CLI
- Java 25 to build the backend artifacts
- An authenticated MongoDB URI
- Application Default Credentials:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 1. Bootstrap remote state

The backend bucket must exist before Terraform initializes. Pick a globally unique name:

```bash
./scripts/bootstrap-state.sh YOUR_PROJECT_ID asia-south1 YOUR_UNIQUE_STATE_BUCKET
cp backend.tf.example backend.tf
```

Edit the bucket in `backend.tf`. Remote state is versioned and private. It still contains sensitive values such as the generated database password, so restrict bucket IAM.

### 2. Configure the environment

```bash
cp terraform.tfvars.example terraform.tfvars
```

Set `project_id`, `config_git_uri`, and `diagnostics_mongodb_uri`. Real `.tfvars` files and Terraform state are ignored by Git.

Create the static NAT address before the full deployment, then add the output as a single `/32` entry in the MongoDB Atlas IP access list:

```bash
terraform apply -target=google_compute_address.nat
terraform output -raw nat_egress_ip
```

Do not allow `0.0.0.0/0` in Atlas.

If the project already has a default Firestore database, import it rather than trying to create another:

```bash
terraform import google_firestore_database.medical_metadata \
  "projects/YOUR_PROJECT_ID/databases/(default)"
```

### 3. Create the artifact bucket and publish the release

The first targeted apply solves the normal bootstrapping dependency: VM instances need JARs from a bucket that Terraform has not created yet.

```bash
terraform init
terraform apply -target=google_storage_bucket.artifacts
./scripts/publish-artifacts.sh YOUR_ARTIFACT_BUCKET v1
```

The script runs all six Maven builds and packages the webapp before uploading the release artifacts under `releases/v1/`.

### 4. Plan and deploy

```bash
terraform fmt -recursive
terraform validate
terraform plan -out=cloud-health.tfplan
terraform apply cloud-health.tfplan
```

Cloud SQL, two or more VM instances, load balancing, NAT, and stored data incur charges. Review the plan and the Google Cloud Pricing Calculator before applying.

When `api_domain` is empty, output `api_url` uses HTTP and the reserved IP. For managed HTTPS, set `api_domain`. If Terraform manages DNS, also set `create_dns_zone = true` and `dns_zone_dns_name`; then delegate the output name servers at the domain registrar. If DNS is external, create an A record pointing to `load_balancer_ip`. Certificate provisioning begins after DNS resolves.

## Optional golden image

The instance startup script can install Java/Node itself, while the Packer image shortens replacement time and demonstrates immutable custom-image management:

```bash
cd images
packer init cloud-health.pkr.hcl
packer build -var project_id=YOUR_PROJECT_ID cloud-health.pkr.hcl
```

Then set:

```hcl
source_image = "projects/YOUR_PROJECT_ID/global/images/family/cloud-health-java25"
```

The JRE package defaults to `openjdk-25-jre-headless`. If the selected base-image repository uses a different Java 25 package, set `java_package` or bake the golden image before deploying the MIG.

## Validate deployment

Test externally through the load balancer:

```bash
./scripts/smoke-test.sh "$(terraform output -raw api_url)"
```

Lecturer-style recording endpoints are available from Terraform outputs:

```bash
terraform output -raw eureka_url
terraform output -raw config_server_url
terraform output -raw api_url
terraform output -raw webapp_url
```

In Google Cloud Console, the Load balancing page shows `lb-api-gateway`, `lb-platform-configserver`, and `lb-webapp`. The platform load balancer has two frontends on the same IP: port `8888` for Config Server and port `8761` for the Eureka dashboard.

Inspect a VM without exposing SSH publicly:

```bash
gcloud compute ssh INSTANCE_NAME \
  --zone=INSTANCE_ZONE \
  --tunnel-through-iap \
  --command='sudo -u cloudhealth env PM2_HOME=/home/cloudhealth/.pm2 pm2 status && curl -fsS localhost:8090/healthz | jq'
```

Expected PM2 processes are `config-server`, `discovery-server` (registered with Eureka as `SERVICE-REGISTRY`), `api-gateway`, `patient-service`, `diagnostics-service`, `file-service`, `webapp`, `platform-proxy`, and `health-monitor`. The three minimum MIG instances form a peer-aware Eureka registry. Restart persistence is configured through `pm2-cloudhealth.service`.

## Release and rollback

Publish a new version, update `release_version`, and apply:

```bash
./scripts/publish-artifacts.sh YOUR_ARTIFACT_BUCKET v2
terraform apply -var='release_version=v2'
```

The changed startup metadata produces a new immutable instance template. The regional MIG replaces instances proactively with zero configured unavailability. Roll back by restoring the previous `release_version` and applying again.

## GitHub keyless deployment

Set `github_repository = "owner/repository"` to create the OIDC provider and deployment service account. The provider accepts tokens only for that exact repository on `refs/heads/main`. Use the `workload_identity_provider` and `deployment_service_account` outputs with `google-github-actions/auth`; the workflow needs:

```yaml
permissions:
  contents: read
  id-token: write
```

`github-actions-terraform.yml.example` is a complete keyless deployment workflow. Copy it to `.github/workflows/terraform.yml` in the eventual infrastructure repository and configure its documented repository variables, MongoDB secret, and protected `production` environment.

The deployment account has broad project roles because it manages this entire stack. Use a dedicated course project and tighten the role set if CI only deploys selected components.

## Destruction safety

Cloud SQL and Firestore deletion protection are enabled, while storage buckets use `force_destroy = false`. An ordinary `terraform destroy` intentionally cannot erase clinical data. For a deliberate course-project teardown:

1. Export any required data.
2. Empty or archive both buckets.
3. Set `database_deletion_protection = false` and apply.
4. Disable Firestore delete protection explicitly or leave the database abandoned.
5. Run and review `terraform destroy`.

Never commit `terraform.tfvars`, state, database exports, credentials, or service-account keys.

## Project Details

| Property | Value |
|---|---|
| Student | Hiruna Dissanayake |
| Student number | `241711024` |
| GCP project | `cloud-health-506015-hiruna` |
