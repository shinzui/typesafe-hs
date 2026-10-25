#!/bin/sh
set -eu

usage() { echo "usage: $0 [--write]" >&2; exit 2; }
write=false
case "${1:-}" in
  '') [ "$#" -eq 0 ] || usage ;;
  --write) [ "$#" -eq 1 ] || usage; write=true ;;
  *) usage ;;
esac
for tool in curl jq diff; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing tool: $tool" >&2; exit 2; }
done
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
url=${TYPESAFE_OPENAPI_URL:-https://api.typesafe.ai/openapi.json}
if ! curl -fsS --max-time 30 "$url" -o "$tmp/published.json"; then
  echo "could not fetch $url" >&2; exit 2
fi
if ! jq -e -S . "$tmp/published.json" > "$tmp/new.json" ||
   ! jq -e -S . "$root/spec/openapi.json" > "$tmp/old.json"; then
  echo "invalid or unreadable OpenAPI document" >&2; exit 2
fi
status=0
diff -u "$tmp/old.json" "$tmp/new.json" || status=$?
case "$status" in
  0) echo "spec/openapi.json is current (info.version $(jq -r '.info.version' "$tmp/new.json"))" ;;
  1) echo "spec/openapi.json has drifted from $url"
     if "$write"; then cp "$tmp/new.json" "$root/spec/openapi.json"; else exit 1; fi ;;
  *) echo "could not compare OpenAPI documents" >&2; exit 2 ;;
esac
