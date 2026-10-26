#!/bin/bash
# Exports the Developer ID Application certificate and its private key from the login
# keychain and stores them as secrets in the "release" environment on GitHub.
# Only the Developer ID identity is uploaded (not other signing certificates), under a
# random password that is generated here and never printed. Nothing is left on disk.
#
# Usage: scripts/upload-signing-cert.sh [exported.p12] [owner/repo]
#
# Without a file it exports straight from the keychain. macOS refuses that for some keys
# (Xcode-created ones); then export the certificate from Keychain Access instead, copy its
# password to the clipboard, and pass the .p12 file. The password is read from the clipboard,
# or set NO_PASSWORD=1 for a .p12 exported without one. Either way the uploaded copy gets a
# fresh random password.
set -euo pipefail
umask 077

p12="${1:-}"
repo="${2:-SagenKoder/nudge}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export P12_PW="$(/usr/bin/openssl rand -base64 24)"

if [[ -n "$p12" ]]; then
    if [[ "${NO_PASSWORD:-}" == 1 ]]; then ALL_PW=""; else ALL_PW="$(pbpaste)"; fi
    export ALL_PW
    cp "$p12" "$work/all.p12"
else
    export ALL_PW="$(/usr/bin/openssl rand -base64 24)"
    echo "Exporting signing identities (macOS will ask for permission)…"
    security export -k ~/Library/Keychains/login.keychain-db -t identities -f pkcs12 -P "$ALL_PW" -o "$work/all.p12" >/dev/null
fi

# /usr/bin/openssl is LibreSSL, whose PKCS#12 defaults are ones macOS `security import` can read.
/usr/bin/openssl pkcs12 -in "$work/all.p12" -passin env:ALL_PW -nodes -out "$work/all.pem" 2>/dev/null \
    || { echo "Could not open the .p12. Is its password on the clipboard?"; exit 1; }
/usr/bin/python3 -I - "$work" <<'EOF'
import re, sys, pathlib
work = pathlib.Path(sys.argv[1])
bags = re.findall(r"(Bag Attributes.*?-----END [A-Z ]+-----)", (work / "all.pem").read_text(), re.S)
key_id = lambda bag: re.search(r"localKeyID: ([0-9A-F ]+)", bag).group(1).strip()
certs = [b for b in bags if "friendlyName: Developer ID Application" in b and "BEGIN CERTIFICATE" in b]
if len(certs) != 1:
    sys.exit(f"Expected exactly one Developer ID Application certificate, found {len(certs)}")
keys = [b for b in bags if "PRIVATE KEY" in b and key_id(b) == key_id(certs[0])]
if len(keys) != 1:
    sys.exit("The private key for the Developer ID certificate is not in the login keychain")
(work / "cert.pem").write_text(certs[0])
(work / "key.pem").write_text(keys[0])
EOF
/usr/bin/openssl pkcs12 -export -in "$work/cert.pem" -inkey "$work/key.pem" \
    -name "Developer ID Application" -passout env:P12_PW -out "$work/devid.p12"

subject="$(/usr/bin/openssl pkcs12 -in "$work/devid.p12" -passin env:P12_PW -nokeys 2>/dev/null \
    | /usr/bin/openssl x509 -noout -subject)"
echo "Uploading: ${subject#*CN=}" | sed 's/[,/].*//'

base64 -i "$work/devid.p12" | gh secret set DEVELOPER_ID_P12 -e release -R "$repo"
printf '%s' "$P12_PW" | gh secret set DEVELOPER_ID_P12_PASSWORD -e release -R "$repo"
echo "Done. Secrets in the release environment:"
gh secret list -e release -R "$repo"
