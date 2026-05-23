#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# One-button deploy script for this repo
# Usage:
#   AWS_ACCOUNT_ID=123456789012 AWS_REGION=us-east-1 ./scripts/one-button-deploy.sh

# Defaults (override by environment)
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-}
ECR_REPO_NAME=${ECR_REPO_NAME:-sample-app}
DOCKER_TAG=${DOCKER_TAG:-$(date +%Y%m%d%H%M%S)}
TERRAFORM_DIR=${TERRAFORM_DIR:-main.tf}
APP_DIR=${APP_DIR:-app}
HELM_CHART_PATH=${HELM_CHART_PATH:-helm/sample-app}
HELM_RELEASE_NAME=${HELM_RELEASE_NAME:-sample-app}
EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-main-eks-cluster}

if [[ -z "${AWS_ACCOUNT_ID}" ]]; then
  echo "ERROR: AWS_ACCOUNT_ID is not set. Export your AWS account ID or set environment variable AWS_ACCOUNT_ID." >&2
  exit 1
fi

ECR_REGISTRY=${ECR_REGISTRY:-${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com}

echo "Starting one-button deploy"
echo "AWS_REGION=${AWS_REGION} ECR_REGISTRY=${ECR_REGISTRY} DOCKER_TAG=${DOCKER_TAG}"

check_cmds=(terraform aws docker kubectl helm)
for cmd in "${check_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command '$cmd' not found. Install it on the Jenkins agent and retry." >&2
    exit 1
  fi
done

echo "Running Terraform (init -> plan -> apply) in ${TERRAFORM_DIR}"
pushd "${TERRAFORM_DIR}" >/dev/null
terraform init -input=false
terraform plan -out=tfplan -input=false
terraform apply -auto-approve tfplan
terraform output -json || true
popd >/dev/null

echo "Ensure ECR repository exists: ${ECR_REPO_NAME}"
if ! aws ecr describe-repositories --repository-names "${ECR_REPO_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws ecr create-repository --repository-name "${ECR_REPO_NAME}" --region "${AWS_REGION}"
fi

echo "Logging into ECR: ${ECR_REGISTRY}"
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "Building Docker image"
pushd "${APP_DIR}" >/dev/null
docker build -t "${ECR_REGISTRY}/${ECR_REPO_NAME}:${DOCKER_TAG}" .
popd >/dev/null

echo "Pushing image to ECR"
docker push "${ECR_REGISTRY}/${ECR_REPO_NAME}:${DOCKER_TAG}"

echo "Updating kubeconfig for EKS cluster: ${EKS_CLUSTER_NAME}"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${EKS_CLUSTER_NAME}"

echo "Deploying with Helm"
helm upgrade --install "${HELM_RELEASE_NAME}" "${HELM_CHART_PATH}" \
  --set image.repository="${ECR_REGISTRY}/${ECR_REPO_NAME}" \
  --set image.tag="${DOCKER_TAG}" \
  --values "${HELM_CHART_PATH}/values.yaml" \
  --wait --timeout 5m

echo "Verifying deployment"
kubectl get pods,svc -n default

echo "Deployment complete: ${ECR_REGISTRY}/${ECR_REPO_NAME}:${DOCKER_TAG}"
