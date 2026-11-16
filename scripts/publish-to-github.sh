#!/usr/bin/env bash
# Publish project changes to the configured Git remote, without force-pushing.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v git >/dev/null || { echo 'Git is required.'; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null || { echo 'Initialize the local Git repository first.'; exit 1; }
if [[ -f .env || -d data ]]; then echo 'Verify that environment files and scan data are ignored before publishing.'; fi
git remote get-url origin >/dev/null || { echo 'Configure a Git remote named origin first.'; exit 1; }
if [[ -z $(git config user.name || :) || -z $(git config user.email || :) ]]; then echo 'Configure git user.name and git user.email.'; exit 1; fi
git add .
if ! git diff --cached --quiet; then git commit -m 'Update accessibility assessment prototype'; fi
git push origin HEAD
