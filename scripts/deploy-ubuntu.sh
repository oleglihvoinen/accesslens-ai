#!/usr/bin/env bash
# Install AccessLens as an isolated service; does NOT edit the existing vik.ooo Nginx vhost.
set -euo pipefail
if [[ $(id -u) -ne 0 ]]; then echo 'Run with sudo: sudo bash scripts/deploy-ubuntu.sh'; exit 1; fi
SOURCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET=/opt/accesslens-ai
SERVICE=accesslens-ai
USER_NAME=accesslens
if ! command -v node >/dev/null || ! node -e 'process.exit(+process.versions.node.split(".")[0]>=22?0:1)'; then echo 'Node.js >= 22 is required.'; exit 1; fi
if ! command -v npm >/dev/null; then echo 'npm is required.'; exit 1; fi
if ! command -v rsync >/dev/null; then echo 'Please install rsync (sudo apt install rsync).'; exit 1; fi
if ! id "$USER_NAME" >/dev/null 2>&1; then useradd --system --home-dir /var/lib/accesslens --create-home --shell /usr/sbin/nologin "$USER_NAME"; fi
install -d -o "$USER_NAME" -g "$USER_NAME" -m 0750 /var/lib/accesslens
install -d -m 0755 "$TARGET" /etc/accesslens /etc/nginx/snippets
if [[ -e "$TARGET/server/index.js" ]]; then cp -a "$TARGET" "${TARGET}.backup.$(date +%Y%m%d%H%M%S)"; fi
rsync -a --delete --exclude=node_modules --exclude=data --exclude=.env --exclude=.git --exclude='*.zip' "$SOURCE_DIR/" "$TARGET/"
cd "$TARGET"
npm install --omit=dev --no-audit --no-fund
chown -R "$USER_NAME":"$USER_NAME" "$TARGET" /var/lib/accesslens
if [[ ! -f /etc/accesslens/accesslens.env ]]; then
  SECRET=$(openssl rand -hex 32)
  cat > /etc/accesslens/accesslens.env <<ENV
PORT=4117
HOST=127.0.0.1
BASE_PATH=/accesslens
DATA_DIR=/var/lib/accesslens
SCAN_ACCESS_TOKEN=$SECRET
SCAN_ALLOWED_HOSTS=vik.ooo,haesiivooja.fi
MAX_SCAN_PER_HOUR=20
AI_ENABLED=true
OPENAI_MODEL=gpt-4.1-mini
OPENAI_API_KEY=
PLAYWRIGHT_BROWSERS_PATH=/opt/accesslens-ai/.pw-browsers
HOME=/var/lib/accesslens
ENV
  chmod 0600 /etc/accesslens/accesslens.env
  echo "Generated owner access token in /etc/accesslens/accesslens.env (do not publish it)."
else
  echo 'Preserved existing /etc/accesslens/accesslens.env, including its secrets.'
fi
install -d -o "$USER_NAME" -g "$USER_NAME" /opt/accesslens-ai/.pw-browsers
sudo -u "$USER_NAME" env PLAYWRIGHT_BROWSERS_PATH=/opt/accesslens-ai/.pw-browsers HOME=/var/lib/accesslens /usr/bin/env npx playwright install chromium
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
EnvironmentFile=/etc/accesslens/accesslens.env
ExecStart=$(command -v node) $TARGET/server/index.js
Restart=on-failure
RestartSec=4
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/accesslens
PrivateTmp=true
UMask=0077
MemoryMax=1500M
CPUQuota=150%
[Install]
WantedBy=multi-user.target
UNIT
cat >/etc/nginx/snippets/accesslens.conf <<'NGINX'
# Include within the existing vik.ooo HTTPS server { } block.
location = /accesslens { return 301 /accesslens/; }
location /accesslens/ {
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
curl --fail --silent http://127.0.0.1:4117/accesslens/api/health || { echo 'Health check failed; journalctl -u accesslens-ai'; exit 1; }
echo
echo 'Installed service and Nginx snippet; existing portfolio untouched.'
echo 'NEXT: edit the vik.ooo HTTPS server block and add: include /etc/nginx/snippets/accesslens.conf;'
echo 'Then: sudo nginx -t && sudo systemctl reload nginx'
echo 'Before allowing scans of public sites, enforce outbound firewall restrictions against SSRF/DNS rebinding.'
