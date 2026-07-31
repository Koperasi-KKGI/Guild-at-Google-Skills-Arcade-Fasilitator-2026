#!/bin/bash
# ==============================================================================
# Script Name : purwananet-Task1-sampai-Task5-Secure-Software-Delivery-Challenge-Lab.sh
# Lab ID      : GSP521 (Secure Software Delivery: Challenge Lab)
# Region      : europe-west1
# ==============================================================================

set -e

echo "=== [2/5] Inisialisasi Variabel Lingkungan ==="
export PROJECT_ID=$(gcloud config get-value project)
export REGION="europe-west1"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo "Project ID: $PROJECT_ID"
echo "Region    : $REGION"

echo "=== [TASK 2] Konfigurasi Awal Cloud Build & Submit Build Pertama ==="
# Tambahkan Role IAM untuk Cloud Build service account (Task 2)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/ondemandscanning.admin"

cd ~/sample-app

# Mengganti placeholder <image-name> pada cloudbuild.yaml bawaan
sed -i "s|<image-name>|${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image|g" cloudbuild.yaml

echo "Submit build pertama untuk Task 2 (Push ke scanning-repo)..."
gcloud builds submit . --config cloudbuild.yaml


echo "=== [TASK 3] Konfigurasi Binary Authorization & KMS ==="
# 1. Buat Attestor Note
cat <<EOF > note.json
{
  "attestation": {
    "hint": {
      "human_readable_name": "Container Vulnerabilities attestation authority"
    }
  }
}
EOF

curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  --data @note.json \
  "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/?noteId=vulnerability_note" || true

# Buat Attestor
gcloud container binauthz attestors create vulnerability-attestor \
  --attestation-authority-note=vulnerability_note \
  --attestation-authority-note-project=${PROJECT_ID} || true

# Set IAM Policy untuk Attestor Note
curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  --data "{
    \"policy\": {
      \"bindings\": [
        {
          \"role\": \"roles/containeranalysis.notes.occurrences.viewer\",
          \"members\": [
            \"serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com\"
          ]
        }
      ]
    }
  }" \
  "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/vulnerability_note:setIamPolicy"

# 2. Buat Keyring & Key KMS
gcloud kms keyrings create binauthz-keys --location=global || true

gcloud kms keys create lab-key \
  --location=global \
  --keyring=binauthz-keys \
  --purpose=asymmetric-signing \
  --default-algorithm=rsa-sign-pkcs1-4096-sha256 || true

# Hubungkan KMS Key ke Attestor
gcloud container binauthz attestors public-keys add \
  --attestor=vulnerability-attestor \
  --keyversion-project=${PROJECT_ID} \
  --keyversion-location=global \
  --keyring=binauthz-keys \
  --key=lab-key \
  --keyversion=1 || true

# 3. Update Policy Binary Authorization
cat <<EOF > policy.yaml
defaultAdmissionRule:
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCING_DEFAULT_UNCHECKED
  requireAttestationsBy:
  - projects/${PROJECT_ID}/attestors/vulnerability-attestor
globalPolicyEvaluationMode: ENABLE
EOF

gcloud container binauthz policy import policy.yaml


echo "=== [TASK 4] Update Pipeline CI/CD dengan Scanning & Tambah Role IAM ==="
# Tambahkan Role IAM sisa untuk Task 4
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/binaryauthorization.attestorsViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/cloudkms.signerVerifier"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/containeranalysis.notes.attacher"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/cloudkms.signerVerifier"

cd ~/sample-app
# Instal Custom Build step (binauthz-attestation)
git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git
cd cloud-builders-community/binauthz-attestation
gcloud builds submit . --config cloudbuild.yaml
cd ~/sample-app
rm -rf cloud-builders-community

# Tulis ulang cloudbuild.yaml dengan pipeline LENGKAP untuk Task 4
cat <<EOF > cloudbuild.yaml
steps:

- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']

- id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image']

- id: scan
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    (gcloud artifacts docker images scan \
    ${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image \
    --location us \
    --format="value(response.scan)") > /workspace/scan_id.txt

- id: severity check
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
      gcloud artifacts docker images list-vulnerabilities \$(cat /workspace/scan_id.txt) \
      --format="value(vulnerability.effectiveSeverity)" | if grep -Fxq CRITICAL; \
      then echo "Failed vulnerability check for CRITICAL level" && exit 1; else echo \
      "No CRITICAL vulnerability found, congrats !" && exit 0; fi

- id: 'create-attestation'
  name: 'gcr.io/${PROJECT_ID}/binauthz-attestation:latest'
  args:
    - '--artifact-url'
    - '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image'
    - '--attestor'
    - 'vulnerability-attestor'
    - '--keyversion'
    - 'projects/${PROJECT_ID}/locations/global/keyRings/binauthz-keys/cryptoKeys/lab-key/cryptoKeyVersions/1'

- id: "push-to-prod"
  name: 'gcr.io/cloud-builders/docker'
  args: 
    - 'tag' 
    - '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image'
    - '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-prod-repo/sample-image:latest'

- id: "push-to-prod-final"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-prod-repo/sample-image:latest']

- id: 'deploy-to-cloud-run'
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    gcloud run deploy auth-service --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-prod-repo/sample-image:latest \
    --binary-authorization=default --region=${REGION} --allow-unauthenticated

images:
  - ${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image
EOF

echo "Submit build kedua (Pipeline Task 4 - Diekspektasikan FAILED karena ada vulnerability)..."
gcloud builds submit . --config cloudbuild.yaml || true


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
