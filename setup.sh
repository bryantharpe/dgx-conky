#!/bin/bash
# Run once after cloning to wire up paths and create your .env.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Stamp the repo path into the Conky config and autostart entry
sed -i "s|REPO_DIR|${REPO_DIR}|g" "$REPO_DIR/dgx.conkyrc" "$REPO_DIR/dgx-widget.desktop"

# Copy .env if not already present
if [ ! -f "$REPO_DIR/.env" ]; then
  cp "$REPO_DIR/.env.example" "$REPO_DIR/.env"
  echo "Created .env — edit it to set DGX_HOST, DGX_USER, and (optionally) DGX_SSH_KEY."
else
  echo ".env already exists, skipping."
fi

chmod +x "$REPO_DIR/dgx_metrics.sh"
echo "Done. Install the autostart entry with:"
echo "  cp $REPO_DIR/dgx-widget.desktop ~/.config/autostart/"
