#!/bin/bash
set -eu

export PATH=/opt/terraform:$PATH

export GOOGLE_CREDENTIALS=${GCP_SERVICE_ACCOUNT_KEY}
export GOOGLE_PROJECT=${GCP_PROJECT_ID}
export GOOGLE_REGION=${GCP_REGION}

google_creds_json=$(mktemp)
echo $GCP_SERVICE_ACCOUNT_KEY > $google_creds_json
gcloud auth activate-service-account --key-file $google_creds_json
gcloud config set project ${GCP_PROJECT_ID}
gcloud config set compute/region ${GCP_REGION}

# us: ops-manager-us/pcf-gcp-1.9.2.tar.gz -> ops-manager-us/pcf-gcp-1.9.2.tar.gz
pcf_opsman_bucket_path=$(grep -i 'us:.*.tar.gz' pivnet-opsmgr/*GCP.yml | cut -d' ' -f2)

# ops-manager-us/pcf-gcp-1.9.2.tar.gz -> opsman-pcf-gcp-1-9-2
pcf_opsman_image_name=$(echo $pcf_opsman_bucket_path | sed 's%.*/\(.*\).tar.gz%opsman-\1%' | sed 's/\./-/g')

mkdir terraform && cd terraform

cat > image.tf <<EOF
resource "google_compute_image" "ops-mgr" {
  name = "$pcf_opsman_image_name"
  project = "$GCP_PROJECT_ID"
  family = "pcf-opsman"

  raw_disk {
    source = "http://storage.googleapis.com/${pcf_opsman_bucket_path}"
  }
}
EOF

if [[ -z $(gcloud compute images list | grep $pcf_opsman_image_name) ]]; then
  echo "creating image ${pcf_opsman_image_name}"
  set +e
  terraform apply
else
  echo "image ${pcf_opsman_image_name} already exists"
fi