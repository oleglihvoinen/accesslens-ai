#!/usr/bin/env bash
# Adds standalone AccessLens AI case page to existing Vite portfolio's public assets, with backups.
set -euo pipefail
VITE_SOURCE="${1:?Usage: bash scripts/install-portfolio-case.sh /path/to/vite-project}"
SCRIPT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -f "$VITE_SOURCE/package.json" || ! -d "$VITE_SOURCE/public" ]]; then echo "Vite portfolio not found at $VITE_SOURCE"; exit 1; fi
DEST="$VITE_SOURCE/public/case-studies/accesslens-ai"
mkdir -p "$DEST"
if [[ -f "$DEST/index.html" ]]; then cp -a "$DEST" "${DEST}.backup.$(date +%Y%m%d%H%M%S)"; fi
cp -a "$SCRIPT_ROOT/portfolio-integration/portfolio-case/". "$DEST/"
echo "Case-study public files copied to: $DEST"
cd "$VITE_SOURCE"
npm run build
if [[ -f "$VITE_SOURCE/dist/case-studies/accesslens-ai/index.html" ]]; then echo 'Case page build confirmed at /case-studies/accesslens-ai/'; else echo 'Build finished but case route output not found.'; exit 1; fi
echo 'IMPORTANT: Add the featured project card from portfolio-integration/featured-card.jsx to your existing React projects array/grid.'
