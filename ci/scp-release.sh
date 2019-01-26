#!/bin/bash
set -eu

# Expected environment variables:
# TRAVIS_REPO_SLUG, TRAVIS_TAG
# STORAGE_USER, STORAGE_PRIVATE_KEY, STORAGE_HOST, STORAGE_PORT, STORAGE_PATH

RELEASE_FILE_CONTENT_TYPE="audio/mpeg"
STORAGE_PRIVATE_KEY_FILE="storage.key"

echo ":: Fetching a GitHub release associated with [${TRAVIS_TAG}]..."

RELEASE_JSON="$(curl \
  --silent \
  --fail \
  --show-error \
  --retry 3 \
  --request GET \
  --header "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${TRAVIS_REPO_SLUG}/releases/tags/${TRAVIS_TAG}"
)"

RELEASE_FILE_JSON="$(
  echo "${RELEASE_JSON}" | jq --raw-output "
    .assets |
    .[] |
    select(.content_type = \"${RELEASE_FILE_CONTENT_TYPE}\")
  "
)"

RELEASE_FILE_URL="$(echo "${RELEASE_FILE_JSON}" | jq --raw-output ".browser_download_url")"
RELEASE_FILE_NAME="$(echo "${RELEASE_FILE_JSON}" | jq --raw-output ".name")"

# Force remove every file we are going to create.

trap 'rm -f "${RELEASE_FILE_NAME}" "${STORAGE_PRIVATE_KEY_FILE}"' EXIT

echo ":: Downloading the GitHub release file..."

curl \
  --silent \
  --fail \
  --show-error \
  --retry 3 \
  --location "${RELEASE_FILE_URL}" \
  --output "${RELEASE_FILE_NAME}"

echo ":: Uploading the GitHub release file to the remote storage..."

echo "${STORAGE_PRIVATE_KEY}" > "${STORAGE_PRIVATE_KEY_FILE}"
chmod u+rw,go= "${STORAGE_PRIVATE_KEY_FILE}"

ssh-keyscan -p "${STORAGE_PORT}" "${STORAGE_HOST}" >> ~/.ssh/known_hosts

scp -i "${STORAGE_PRIVATE_KEY_FILE}" -P "${STORAGE_PORT}" "${RELEASE_FILE_NAME}" ${STORAGE_USER}@${STORAGE_HOST}:${STORAGE_PATH}

echo ":: Success!"
