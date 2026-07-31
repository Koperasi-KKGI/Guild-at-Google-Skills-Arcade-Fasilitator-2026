#!/bin/bash
# ==============================================================================
# Script Name : purwananet-Task1-sampai-Task5-Secure-Software-Delivery-Challenge-Lab.sh
# Lab ID      : GSP521 (Secure Software Delivery: Challenge Lab)
# Region      : europe-west1
# ==============================================================================

set -e

echo "=== [1/5] Inisialisasi Variabel Lingkungan ==="
export PROJECT_ID=$(gcloud config get-value project)
export REGION="europe-west1"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo "Project ID: $PROJECT_ID"
echo "Region    : $REGION"

echo "=== [TASK 1] Mengaktifkan API dan Menyiapkan Artifact Registry ==="
gcloud services enable \
  cloudkms.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  container.googleapis.com \
  containerregistry.googleapis.com \
  artifactregistry.googleapis.com \
  containerscanning.googleapis.com \
  ondemandscanning.googleapis.com \
  binaryauthorization.googleapis.com

mkdir -p ~/sample-app
cd ~/sample-app
gcloud storage cp gs://spls/gsp521/* .

# Membuat repositori Artifact Registry
gcloud artifacts repositories create artifact-scanning-repo \
  --repository-format=docker \
  --location=$REGION \
  --description="Scanning repository" || true

gcloud artifacts repositories create artifact-prod-repo \
  --repository-format=docker \
  --location=$REGION \
  --description="Production repository" || true

  