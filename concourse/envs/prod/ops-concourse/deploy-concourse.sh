#!/bin/bash

# declare ver vars
CONCOURSE_RELEASE_VERSION=4.2.4
UAA_RELEASE_VERSION=72.0
CREDHUB_RELEASE_VERSION=2.1.5
POSTGRES_RELEASE_VERSION=36
STEMCELL_RELEASE_VERSION='97.71'

# get concourse && garden
pivnet dlpf -p p-concourse -g '*.tgz' -r "$CONCOURSE_RELEASE_VERSION"

# get bits
wget https://bosh.io/d/github.com/cloudfoundry/uaa-release?v=$UAA_RELEASE_VERSION -O uaa-release-$UAA_RELEASE_VERSION.tgz
wget https://bosh.io/d/github.com/pivotal-cf/credhub-release?v=$CREDHUB_RELEASE_VERSION -O credhub-release-$CREDHUB_RELEASE_VERSION.tgz
wget https://bosh.io/d/github.com/cloudfoundry/postgres-release?v=$POSTGRES_RELEASE_VERSION -O postgres-release-$POSTGRES_RELEASE_VERSION.tgz

# get the stemcell for the deployment
pivnet dlpf -p stemcells-ubuntu-xenial -g '*vsphere-esxi*.tgz' -r "$STEMCELL_RELEASE_VERSION"

# upload the bits
bosh -e standalone upload-release uaa-release-*.tgz
bosh -e standalone upload-release credhub-*.tgz
bosh -e standalone upload-release postgres-*.tgz
bosh upload-stemcell light-bosh-stemcell-*.tgz

# local path to https://github.com/concourse/concourse-bosh-deployment
if [ ! -d "./concourse-bosh-deployment" ]; then
  git clone https://github.com/concourse/concourse-bosh-deployment
  cd concourse-bosh-deployment
else
  cd concourse-bosh-deployment
  git checkout master && git pull
fi

# get the cloud config from GCP if using this on AWS (compare and edit)
#bosh config --name concourse-platform-cloud-config --type cloud
CONCOURSE_BOSH_DEPLOYMENT=./concourse-bosh-deployment
#git checkout v$CONCOURSE_RELEASE_VERSION
git checkout release/4.2.x
cd ..
# deploy concourse pass in required vars and details
bosh -e standalone -n deploy -d concourse $CONCOURSE_BOSH_DEPLOYMENT/cluster/concourse.yml \
   -l $CONCOURSE_BOSH_DEPLOYMENT/versions.yml \
   -o $CONCOURSE_BOSH_DEPLOYMENT/cluster/operations/basic-auth.yml \
   -o $CONCOURSE_BOSH_DEPLOYMENT/cluster/operations/privileged-http.yml \
   -o $CONCOURSE_BOSH_DEPLOYMENT/cluster/operations/privileged-https.yml \
   -o $CONCOURSE_BOSH_DEPLOYMENT/cluster/operations/tls.yml \
   -o $CONCOURSE_BOSH_DEPLOYMENT/cluster/operations/tls-vars.yml \
   -o $CONCOURSE_BOSH_DEPLOYMENT/cluster/operations/scale.yml \
   -o ../../../operations/static-ips.yml \
   -o ../../../operations/update-azs.yml \
   -o ../../../operations/add-credhub-uaa-to-web.yml \
   --vars-file vars.yml
