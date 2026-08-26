#!/usr/bin/env bash
set -e
# Create the dev directory if it doesn't exist
mkdir -p dev
cd "dev"
# Clone the DevOps repository into 
git clone https://github.com/leanderziehm/devops.git
# Get the current hostname and change into the corresponding VM directory
cd "devops/vms/$(hostname)"
# Run make
make
