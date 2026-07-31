#!/bin/bash
# ==============================================================================
# Script Name : purwananet-Task1-sampai-Task4-Securing-Container-Builds.sh
# Lab Title   : Securing Container Builds (GSP1185)
# Description : Automation script to complete Task 1 through Task 4 sequentially
# ==============================================================================

set -e

echo "=================================================="
echo " Starting Solution Script for GSP1185..."
echo "=================================================="

# ------------------------------------------------------------------------------
# SETUP & WORKSPACE ENVIRONMENT
# ------------------------------------------------------------------------------
echo "[0/4] Preparing Project Environment & Working Directory..."

export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export REGION="us-central1"

# Enable Artifact Registry API
gcloud services enable artifactregistry.googleapis.com

# Clone repository & navigate to working directory
cd ~
rm -rf java-docs-samples
git clone https://github.com/GoogleCloudPlatform/java-docs-samples
cd java-docs-samples/container-registry/container-analysis

# ------------------------------------------------------------------------------
# TASK 1: Standard Repositories
# ------------------------------------------------------------------------------
echo "--------------------------------------------------"
echo "[1/4] Executing Task 1: Creating Standard Maven Repository..."
echo "--------------------------------------------------"

gcloud artifacts repositories create container-dev-java-repo \
    --repository-format=maven \
    --location=$REGION \
    --description="Java package repository for Container Dev Workshop" || true

gcloud artifacts repositories describe container-dev-java-repo \
    --location=$REGION

# ------------------------------------------------------------------------------
# TASK 2: Configure Maven for Artifact Registry
# ------------------------------------------------------------------------------
echo "--------------------------------------------------"
echo "[2/4] Executing Task 2: Configuring Maven & Deploying Artifact..."
echo "--------------------------------------------------"

# Inject Task 2 Maven settings into pom.xml
python3 -c "
import os

project_id = os.environ['PROJECT_ID']
region = os.environ.get('REGION', 'us-central1')

with open('pom.xml', 'r') as f:
    content = f.read()

addition = f'''
  <distributionManagement>
    <snapshotRepository>
      <id>artifact-registry</id>
      <url>artifactregistry://{region}-maven.pkg.dev/{project_id}/container-dev-java-repo</url>
    </snapshotRepository>
    <repository>
      <id>artifact-registry</id>
      <url>artifactregistry://{region}-maven.pkg.dev/{project_id}/container-dev-java-repo</url>
    </repository>
  </distributionManagement>

  <repositories>
    <repository>
      <id>artifact-registry</id>
      <url>artifactregistry://{region}-maven.pkg.dev/{project_id}/container-dev-java-repo</url>
      <releases>
        <enabled>true</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>
  </repositories>

  <build>
    <extensions>
      <extension>
        <groupId>com.google.cloud.artifactregistry</groupId>
        <artifactId>artifactregistry-maven-wagon</artifactId>
        <version>2.2.0</version>
      </extension>
    </extensions>
  </build>
'''

content = content.replace('</project>', addition + '\n</project>')

with open('pom.xml', 'w') as f:
    f.write(content)
"

mvn deploy -DskipTests

# ------------------------------------------------------------------------------
# TASK 3: Remote Repositories
# ------------------------------------------------------------------------------
echo "--------------------------------------------------"
echo "[3/4] Executing Task 3: Creating Remote Repository & Caching Dependencies..."
echo "--------------------------------------------------"

gcloud artifacts repositories create maven-central-cache \
    --project=$PROJECT_ID \
    --repository-format=maven \
    --location=$REGION \
    --description="Remote repository for Maven Central caching" \
    --mode=remote-repository \
    --remote-repo-config-desc="Maven Central" \
    --remote-mvn-repo=MAVEN-CENTRAL || true

gcloud artifacts repositories describe maven-central-cache \
    --location=$REGION

# Inject central repo into pom.xml
python3 -c "
import os

project_id = os.environ['PROJECT_ID']
region = os.environ.get('REGION', 'us-central1')

with open('pom.xml', 'r') as f:
    content = f.read()

central_repo = f'''
    <repository>
      <id>central</id>
      <url>artifactregistry://{region}-maven.pkg.dev/{project_id}/maven-central-cache</url>
      <releases>
        <enabled>true</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>
'''

content = content.replace('</repositories>', central_repo + '\n  </repositories>')

with open('pom.xml', 'w') as f:
    f.write(content)
"

# Create extensions.xml
mkdir -p .mvn
cat > .mvn/extensions.xml << 'EOF'
<extensions xmlns="http://maven.apache.org/EXTENSIONS/1.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/EXTENSIONS/1.0.0 http://maven.apache.org/xsd/core-extensions-1.0.0.xsd">
  <extension>
    <groupId>com.google.cloud.artifactregistry</groupId>
    <artifactId>artifactregistry-maven-wagon</artifactId>
    <version>2.2.0</version>
  </extension>
</extensions>
EOF

rm -rf ~/.m2/repository
mvn compile

# ------------------------------------------------------------------------------
# TASK 4: Virtual Repositories
# ------------------------------------------------------------------------------
echo "--------------------------------------------------"
echo "[4/4] Executing Task 4: Creating Virtual Repository & Final Verification..."
echo "--------------------------------------------------"

# Create policy file
cat > ./policy.json << EOF
[
  {
    "id": "private",
    "repository": "projects/${PROJECT_ID}/locations/${REGION}/repositories/container-dev-java-repo",
    "priority": 100
  },
  {
    "id": "central",
    "repository": "projects/${PROJECT_ID}/locations/${REGION}/repositories/maven-central-cache",
    "priority": 80
  }
]
EOF

# Create virtual repository
gcloud artifacts repositories create virtual-maven-repo \
    --project=${PROJECT_ID} \
    --repository-format=maven \
    --mode=virtual-repository \
    --location=${REGION} \
    --description="Virtual Maven Repo" \
    --upstream-policy-file=./policy.json || true

# Update pom.xml repositories section to use virtual repository
python3 -c "
import os, re

project_id = os.environ['PROJECT_ID']
region = os.environ.get('REGION', 'us-central1')

with open('pom.xml', 'r') as f:
    content = f.read()

virtual_repos = f'''<repositories>
    <repository>
      <id>artifact-registry</id>
      <url>artifactregistry://{region}-maven.pkg.dev/{project_id}/virtual-maven-repo</url>
      <releases>
        <enabled>true</enabled>
      </releases>
      <snapshots>
        <enabled>true</enabled>
      </snapshots>
    </repository>
  </repositories>'''

content = re.sub(r'<repositories>.*?</repositories>', virtual_repos, content, flags=re.DOTALL)

with open('pom.xml', 'w') as f:
    f.write(content)
"

# Re-create cache repository to test pass-through
gcloud artifacts repositories delete maven-central-cache \
    --project=$PROJECT_ID \
    --location=$REGION \
    --quiet

gcloud artifacts repositories create maven-central-cache \
    --project=$PROJECT_ID \
    --repository-format=maven \
    --location=$REGION \
    --description="Remote repository for Maven Central caching" \
    --mode=remote-repository \
    --remote-repo-config-desc="Maven Central" \
    --remote-mvn-repo=MAVEN-CENTRAL

# Build project from virtual repository
rm -rf ~/.m2/repository
mvn compile

echo "=================================================="
echo " All tasks completed successfully! Check progress on Qwiklabs."
echo "=================================================="