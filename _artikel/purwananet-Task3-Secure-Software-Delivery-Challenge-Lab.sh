#!/bin/bash
# ==========================================================================
# GSP521 - Secure Software Delivery: Challenge Lab
# Task 3: Set up Binary Authorization
#   - Create an Attestor (Note + Attestor + IAM policy on note)
#   - Generate a KMS key pair & link it to the Attestor
#   - Update the Binary Authorization policy (REQUIRE_ATTESTATION)
# ==========================================================================
set -e

# ---------------------------------------------------------------------
# LAB VARS
# ---------------------------------------------------------------------
export STUDENT_USERNAME="student-04-215668867a85@qwiklabs.net"   # info saja, tidak dipakai langsung di task ini
export PROJECT_ID="qwiklabs-gcp-03-9a0d7b4b2378"
export REGION="europe-west4"                                     # tidak dipakai di Task 3 (KMS pakai lokasi "global"), tapi tetap disiapkan
export PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')

echo "PROJECT_ID     = ${PROJECT_ID}"
echo "PROJECT_NUMBER = ${PROJECT_NUMBER}"
echo "REGION         = ${REGION}"

# ---------------------------------------------------------------------
# WORKING DIRECTORY
# Task 1 lab ini melakukan: mkdir sample-app && cd sample-app
# Direktori kerja tersebut berlaku untuk seluruh task, termasuk Task 3.
# ---------------------------------------------------------------------
mkdir -p ~/sample-app
cd ~/sample-app
echo "Working dir: $(pwd)"

# ---------------------------------------------------------------------
# Variabel Attestor / Note
# ---------------------------------------------------------------------
export NOTE_ID="vulnerability_note"
export ATTESTOR_ID="vulnerability-attestor"

# ---------------------------------------------------------------------
# 1) Buat file JSON untuk Attestor Note (attestation hint)
# ---------------------------------------------------------------------
echo ">>> [1/9] Membuat file note (vulnerability_note.json)..."
cat > ./vulnerability_note.json << EOM
{
  "attestation": {
    "hint": {
      "human_readable_name": "Container Vulnerabilities attestation authority"
    }
  }
}
EOM

# ---------------------------------------------------------------------
# 2) Buat Note lewat Container Analysis API
# ---------------------------------------------------------------------
echo ">>> [2/9] Membuat Note (${NOTE_ID}) via Container Analysis API..."
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  --data-binary @./vulnerability_note.json \
  "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/?noteId=${NOTE_ID}"
echo ""

# ---------------------------------------------------------------------
# 3) Verifikasi Note yang baru dibuat
# ---------------------------------------------------------------------
echo ">>> [3/9] Verifikasi Note ${NOTE_ID}..."
curl \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/${NOTE_ID}"
echo ""

# ---------------------------------------------------------------------
# 4) Buat Binary Authorization Attestor terhubung ke Note di atas
# ---------------------------------------------------------------------
echo ">>> [4/9] Membuat Attestor ${ATTESTOR_ID}..."
gcloud container binauthz attestors create "${ATTESTOR_ID}" \
  --attestation-authority-note="${NOTE_ID}" \
  --attestation-authority-note-project="${PROJECT_ID}"

# ---------------------------------------------------------------------
# 5) List semua Attestor untuk verifikasi
# ---------------------------------------------------------------------
echo ">>> [5/9] Daftar Attestor:"
gcloud container binauthz attestors list

# ---------------------------------------------------------------------
# 6) Beri IAM policy roles/containeranalysis.notes.occurrences.viewer
#    ke service account Binary Authorization, pada Note tsb
# ---------------------------------------------------------------------
echo ">>> [6/9] Set IAM policy pada Note untuk Binary Authorization SA..."
BINAUTHZ_SA_EMAIL="service-${PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"

cat > ./iam_request.json << EOM
{
  "resource": "projects/${PROJECT_ID}/notes/${NOTE_ID}",
  "policy": {
    "bindings": [
      {
        "role": "roles/containeranalysis.notes.occurrences.viewer",
        "members": [
          "serviceAccount:${BINAUTHZ_SA_EMAIL}"
        ]
      }
    ]
  }
}
EOM

curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  --data-binary @./iam_request.json \
  "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/${NOTE_ID}:setIamPolicy"
echo ""

# ---------------------------------------------------------------------
# 7) Buat KMS keyring "binauthz-keys" (global) + key pair "lab-key" v1
# ---------------------------------------------------------------------
export KEY_LOCATION="global"
export KEYRING="binauthz-keys"
export KEY_NAME="lab-key"
export KEY_VERSION="1"

echo ">>> [7/9] Membuat KMS keyring & key pair..."
gcloud kms keyrings create "${KEYRING}" --location="${KEY_LOCATION}"

gcloud kms keys create "${KEY_NAME}" \
  --keyring="${KEYRING}" --location="${KEY_LOCATION}" \
  --purpose asymmetric-signing \
  --default-algorithm="ec-sign-p256-sha256"

# ---------------------------------------------------------------------
# 8) Kaitkan key (lab-key v1) ke Attestor
# ---------------------------------------------------------------------
echo ">>> [8/9] Mengaitkan ${KEY_NAME} v${KEY_VERSION} ke Attestor ${ATTESTOR_ID}..."
gcloud beta container binauthz attestors public-keys add \
  --attestor="${ATTESTOR_ID}" \
  --keyversion-project="${PROJECT_ID}" \
  --keyversion-location="${KEY_LOCATION}" \
  --keyversion-keyring="${KEYRING}" \
  --keyversion-key="${KEY_NAME}" \
  --keyversion="${KEY_VERSION}"

echo "Attestor sekarang (harus terlihat NUM_PUBLIC_KEYS: 1):"
gcloud container binauthz attestors list

# ---------------------------------------------------------------------
# 9) Update Binary Authorization Policy -> REQUIRE_ATTESTATION
#    pada defaultAdmissionRule, mengacu ke vulnerability-attestor
# ---------------------------------------------------------------------
echo ">>> [9/9] Meng-update Binary Authorization Policy..."
cat > ./policy.yaml << EOM
defaultAdmissionRule:
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  requireAttestationsBy:
  - projects/${PROJECT_ID}/attestors/${ATTESTOR_ID}
globalPolicyEvaluationMode: ENABLE
name: projects/${PROJECT_ID}/policy
EOM

gcloud container binauthz policy import ./policy.yaml

echo "=========================================================="
echo "Task 3 selesai."
echo " - Note        : ${NOTE_ID}"
echo " - Attestor     : ${ATTESTOR_ID}"
echo " - KMS keyring  : ${KEYRING} (${KEY_LOCATION})"
echo " - KMS key      : ${KEY_NAME} v${KEY_VERSION}"
echo " - Policy       : REQUIRE_ATTESTATION -> ${ATTESTOR_ID}"
echo "Silakan klik 'Check my progress' pada Task 3 di Qwiklabs."
echo "=========================================================="