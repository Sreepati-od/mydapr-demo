#!/usr/bin/env bash
set -euo pipefail

# Export DELIVERABLES.md to DELIVERABLES.docx
# Usage: ./scripts/export-deliverables.sh
# Requires: pandoc (installed locally) OR Docker (for containerized pandoc)

MD_FILE="DELIVERABLES.md"
DOCX_FILE="DELIVERABLES.docx"

if [ ! -f "$MD_FILE" ]; then
  echo "Error: $MD_FILE not found in repo root. Run from repo root directory." >&2
  exit 1
fi

convert_with_pandoc() {
  echo "Using local pandoc to convert $MD_FILE -> $DOCX_FILE"
  pandoc "$MD_FILE" -o "$DOCX_FILE" --from markdown --to docx \
    --metadata=title:"Deployment Deliverables" \
    --resource-path=.:./ \
    --embed-resources || return 1
  echo "Created $DOCX_FILE"
}

convert_with_docker() {
  echo "Using Docker pandoc image to convert $MD_FILE -> $DOCX_FILE"
  docker run --rm -v "$(pwd)":/data pandoc/core:3.1 \
    "$MD_FILE" -o "$DOCX_FILE" --from markdown --to docx --metadata=title:"Deployment Deliverables" --embed-resources
  echo "Created $DOCX_FILE via Docker"
}

if command -v pandoc >/dev/null 2>&1; then
  if convert_with_pandoc; then exit 0; fi
  echo "Local pandoc failed, attempting Docker fallback..." >&2
fi

if command -v docker >/dev/null 2>&1; then
  convert_with_docker && exit 0
fi

echo "Neither pandoc nor docker-based pandoc conversion succeeded." >&2
echo "Install pandoc (macOS: brew install pandoc) or Docker, then re-run." >&2
exit 2
