#!/usr/bin/env bash
# Install AccessLens AI as an isolated service without editing an existing Nginx vhost.
set -euo pipefail
if [[ $(id -u) -ne 0 ]]; then echo 'Run with sudo: sudo bash scripts/deploy-ubuntu.sh'; exit 1; fi
SOURCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET=/opt/accesslens-ai
SERVICE=accesslens-ai
USER_NAME=accesslens-ai
if ! command -v node >/dev/null || ! node -e 'process.exit(+process.versions.node.split(".")[0]>=22?0:1)'; then echo 'Node.js >= 22 is required.'; exit 1; fi
if ! command -v npm >/dev/null; then echo 'npm is required.'; exit 1; fi
if ! command -v rsync >/dev/null; then echo 'Please install rsync (sudo apt install rsync).'; exit 1; fi
if ! id "$USER_NAME" >/dev/null 2>&1; then useradd --system --home-dir /var/lib/accesslens-ai --create-home --shell /usr/sbin/nologin "$USER_NAME"; fi
install -d -o "$USER_NAME" -g "$USER_NAME" -m 0750 /var/lib/accesslens-ai
install -d -m 0755 "$TARGET" /etc/accesslens-ai /etc/nginx/snippets
if [[ -e "$TARGET/server/index.js" ]]; then cp -a "$TARGET" "${TARGET}.backup.$(date +%Y%m%d%H%M%S)"; fi
rsync -a --delete --exclude=node_modules --exclude=data --exclude=.env --exclude=.git --exclude='*.zip' "$SOURCE_DIR/" "$TARGET/"
cd "$TARGET"
npm install --omit=dev --no-audit --no-fund
chown -R "$USER_NAME":"$USER_NAME" "$TARGET" /var/lib/accesslens-ai
if [[ ! -f /etc/accesslens-ai/accesslens-ai.env ]]; then
  SECRET=$(openssl rand -hex 32)
  cat > /etc/accesslens-ai/accesslens-ai.env <<ENV
PORT=4117
HOST=127.0.0.1
BASE_PATH=/accesslens-ai
DATA_DIR=/var/lib/accesslens-ai
SCAN_ACCESS_TOKEN=$SECRET
SCAN_ALLOWED_HOSTS=example.com
MAX_SCAN_PER_HOUR=20
AI_ENABLED=true
OPENAI_MODEL=gpt-4.1-mini
OPENAI_API_KEY=
PLAYWRIGHT_BROWSERS_PATH=/opt/accesslens-ai/.pw-browsers
HOME=/var/lib/accesslens-ai
ENV
  chmod 0600 /etc/accesslens-ai/accesslens-ai.env
  echo "Generated owner access token in /etc/accesslens-ai/accesslens-ai.env (do not publish it)."
else
  echo 'Preserved existing /etc/accesslens-ai/accesslens-ai.env, including its secrets.'
fi
install -d -o "$USER_NAME" -g "$USER_NAME" /opt/accesslens-ai/.pw-browsers
sudo -u "$USER_NAME" env PLAYWRIGHT_BROWSERS_PATH=/opt/accesslens-ai/.pw-browsers HOME=/var/lib/accesslens-ai /usr/bin/env npx playwright install chromium
cat >/etc/systemd/system/${SERVICE}.service <<UNIT
[Unit]
Description=AccessLens AI accessibility studio
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$TARGET
EnvironmentFile=/etc/accesslens-ai/accesslens-ai.env
ExecStart=$(command -v node) $TARGET/server/index.js
Restart=on-failure
RestartSec=4
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/accesslens-ai
PrivateTmp=true
UMask=0077
MemoryMax=1500M
CPUQuota=150%
[Install]
WantedBy=multi-user.target
UNIT
cat >/etc/nginx/snippets/accesslens-ai.conf <<'NGINX'
# Include within an existing HTTPS server { } block.
location = /accesslens-ai { return 301 /accesslens-ai/; }
location /accesslens-ai/ {
  proxy_pass http://127.0.0.1:4117;
  proxy_http_version 1.1;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_connect_timeout 7s;
  proxy_read_timeout 100s;
  client_max_body_size 16k;
  proxy_buffering off;
}
NGINX
systemctl daemon-reload
systemctl enable --now "$SERVICE"
sleep 1
curl --fail --silent http://127.0.0.1:4117/accesslens-ai/api/health || { echo 'Health check failed; journalctl -u accesslens-ai'; exit 1; }
echo
echo 'Installed service and Nginx snippet; existing site configurations unchanged.'
echo 'NEXT: edit the appropriate HTTPS server block and add: include /etc/nginx/snippets/accesslens-ai.conf;'
echo 'Then: sudo nginx -t && sudo systemctl reload nginx'
echo 'Before allowing scans of public sites, enforce outbound firewall restrictions against SSRF/DNS rebinding.'
