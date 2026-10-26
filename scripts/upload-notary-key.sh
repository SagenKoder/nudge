#!/bin/bash
# Stores an App Store Connect API key (used for notarization) as secrets in the
# "release" environment on GitHub. The key ID is read from the file name.
#
# Usage: scripts/upload-notary-key.sh ~/Downloads/AuthKey_ABC123XYZ.p8 <issuer-id> [owner/repo]
set -euo pipefail

key_file="${1:?Path to AuthKey_<KEYID>.p8}"
issuer="${2:?Issuer ID from App Store Connect → Users and Access → Integrations}"
repo="${3:-SagenKoder/nudge}"

key_id="$(basename "$key_file" .p8)"
key_id="${key_id#AuthKey_}"
[[ "$key_id" =~ ^[A-Z0-9]{10}$ ]] || { echo "Could not read a key ID from '$key_file'"; exit 1; }
grep -q 'BEGIN PRIVATE KEY' "$key_file" || { echo "'$key_file' does not look like a .p8 key"; exit 1; }

gh secret set NOTARY_KEY_P8 -e release -R "$repo" < "$key_file"
printf '%s' "$key_id" | gh secret set NOTARY_KEY_ID -e release -R "$repo"
printf '%s' "$issuer" | gh secret set NOTARY_ISSUER -e release -R "$repo"
echo "Done. Secrets in the release environment:"
gh secret list -e release -R "$repo"
echo "Now move $key_file into your password manager and delete it here."
