#!/bin/bash
# ==============================================================================
# Script Name : purwananet-Task1-sampai-Task5-Secure-Software-Delivery-Challenge-Lab.sh
# Lab ID      : GSP521 (Secure Software Delivery: Challenge Lab)
# Region      : europe-west1
# ==============================================================================

set -e

echo "=== [5/5] Inisialisasi Variabel Lingkungan ==="
export PROJECT_ID=$(gcloud config get-value project)
export REGION="europe-west1"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo "Project ID: $PROJECT_ID"
echo "Region    : $REGION"

echo "=== [TASK 5] Fix Vulnerability & Redeploy CI/CD Pipeline ==="
cd ~/sample-app

# 1. Perbarui Dockerfile
cat <<EOF > Dockerfile
FROM python:3.8-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
EOF

# 2. Perbarui versi Dependensi
cat <<EOF > requirements.txt
Flask==3.0.3
gunicorn==23.0.0
Werkzeug==3.0.4
EOF

echo "Submit build ketiga (Pipeline Task 5 - Diekspektasikan SUCCESS)..."
gcloud builds submit . --config cloudbuild.yaml

# 3. Buka akses unauthenticated ke Cloud Run
gcloud beta run services add-iam-policy-binding auth-service \
  --region=$REGION \
  --member=allUsers \
  --role=roles/run.invoker

echo "=== Selesai! Silahkan Check My Progress di Google Cloud Skills Boost ==="
