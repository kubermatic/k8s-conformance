#!/usr/bin/env bash

###
### This script can be used after running the conformance tests
### via sonobuoy to retrieve the results and update the files
### in this repository automatically.
###
### Run it from anywhere within this repository, for example
###
###   $ mkdir -p kkp-2.99/1.24
###   $ cd kkp-2.99/1.24
###   $ ../../hack/update-conformance-results.sh 2.99
###
### You probably want to switch to a new Git branch before running
### this script.

set -euo pipefail

KKP_RELEASE="${1:-}"
if [ -z "$KKP_RELEASE" ]; then
  echo "Usage: update-conformance-results.sh KKP_RELEASE"
  exit 1
fi

if [ -z "${KUBECONFIG:-}" ]; then
  echo "No \$KUBECONFIG variable specified."
  exit 1
fi

if ! command -v sonobuoy &>/dev/null; then
  echo "No sonobuoy binary found in \$PATH."
  exit 1
fi

# trim leading 'v'
KKP_RELEASE="${KKP_RELEASE#v}"
KUBERNETES_RELEASE="$(kubectl version --output json | jq -r '.serverVersion | .major + "." + .minor')"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"

echo "KKP release.......: v$KKP_RELEASE"
echo "Kubernetes release: v$KUBERNETES_RELEASE"
echo "Repository root...: $REPO_ROOT"
echo

echo "Retrieving sonobuoy results…"
filename="$(sonobuoy retrieve)"

echo "Extracting archive…"
tar xzf -- "$filename"

if [ ! -d plugins/e2e/results/global ]; then
  echo "Error: Results did not contain expected plugins directory."
  exit 1
fi

RESULTS="$(realpath plugins/e2e/results/global)"
cd "$REPO_ROOT"

# prepare directory
echo "Updating release info…"
RELEASE_DIR="v$KUBERNETES_RELEASE/kubermatic"
mkdir -p "$RELEASE_DIR"

# always overwrite the product info with the template
cp hack/template/PRODUCT.yaml "$RELEASE_DIR"

if [ ! -f "$RELEASE_DIR/README.md" ]; then
  echo "Creating new README.md."
  cp hack/template/README.md "$RELEASE_DIR"
fi

sed -i "s/__KKP_RELEASE__/v$KKP_RELEASE/g"               "$RELEASE_DIR"/*
sed -i "s/__KUBERNETES_RELEASE__/v$KUBERNETES_RELEASE/g" "$RELEASE_DIR"/*

# copy the test results
cp "$RESULTS"/* "$RELEASE_DIR"

echo "Done."
