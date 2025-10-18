#!/bin/bash

set -ouex pipefail

BASEDIR="$(dirname "$(realpath "$0")")"

### Install packages
${BASEDIR}/scripts/docker.sh # BUILD_DOCKER=1 to install shell tools
${BASEDIR}/scripts/clean.sh
