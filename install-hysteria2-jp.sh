#!/usr/bin/env bash
# One-shot Hysteria2 (latest) installer for Ubuntu 24.04
# Run ON the VPS as root (provider web/VNC console if SSH is closed):
#
#   export GH_PAT='github_pat_...'   # optional: auto-update GitHub subscription
#   bash install-hysteria2-jp.sh
#
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if [[ $(id -u) -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

# Pre-generated secrets (override with env if desired)
HY2_AUTH="${HY2_AUTH:-4cc12a70e4e0a01b976e1f3299ed02c4}"
HY2_OBFS="${HY2_OBFS:-51fada1af570cc8f84b56cde870064eb}"
PRIMARY_PORT="${PRIMARY_PORT:-443}"
HOP_PORT="${HOP_PORT:-20000}"
NODE_NAME_PRIMARY="${NODE_NAME_PRIMARY:-🇯🇵 Япония}"
NODE_NAME_HOP="${NODE_NAME_HOP:-🇯🇵 Япония-Hop}"
GH_REPO="${GH_REPO:-maximf71/subscription_vpn}"
GH_PAT="${GH_PAT:-}"

echo "==> Detecting public IP"
SERVER_IP="$(curl -4 -fsS --connect-timeout 8 https://api.ipify.org \
  || curl -4 -fsS --connect-timeout 8 https://ifconfig.me \
  || hostname -I | awk '{print $1}')"
echo "    SERVER_IP=${SERVER_IP}"

echo "==> Packages"
apt-get update -qq
apt-get install -y -qq curl ca-certificates openssl jq ufw git openssh-server >/dev/null

echo "==> Ensure SSH listens on 39266"
mkdir -p /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/99-custom-port.conf <<'SSH'
Port 39266
PasswordAuthentication yes
PermitRootLogin yes
SSH
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null || true
systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true

echo "==> TCP BBR + UDP buffers"
cat >/etc/sysctl.d/99-hysteria-bbr.conf <<'SYS'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
SYS
sysctl -p /etc/sysctl.d/99-hysteria-bbr.conf >/dev/null || true

echo "==> Installing latest Hysteria2"
bash <(curl -fsSL https://get.hy2.sh/)
hysteria version || true

echo "==> TLS certificate (self-signed, no domain)"
mkdir -p /etc/hysteria
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout /etc/hysteria/server.key \
  -out /etc/hysteria/server.crt \
  -subj "/CN=${SERVER_IP}" -days 3650 2>/dev/null
chmod 600 /etc/hysteria/server.key

write_config() {
  local file="$1" listen="$2"
  cat >"$file" <<EOF
listen: :${listen}

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: ${HY2_AUTH}

obfs:
  type: salamander
  salamander:
    password: ${HY2_OBFS}

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false

bandwidth:
  up: 1 gbps
  down: 1 gbps

ignoreClientBandwidth: false

speedTest: true

masquerade:
  type: proxy
  proxy:
    url: https://www.cloudflare.com/
    rewriteHost: true

outbounds:
  - name: direct
    type: direct
EOF
}

write_config /etc/hysteria/config.yaml "$PRIMARY_PORT"
write_config /etc/hysteria/config-hop.yaml "$HOP_PORT"

id hysteria >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin hysteria || true
chown -R hysteria:hysteria /etc/hysteria
chmod 640 /etc/hysteria/server.key /etc/hysteria/server.crt /etc/hysteria/*.yaml

cat >/etc/systemd/system/hysteria-server-hop.service <<'UNIT'
[Unit]
Description=Hysteria Server Hop
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config-hop.yaml
WorkingDirectory=/etc/hysteria
User=hysteria
Group=hysteria
Environment=HYSTERIA_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
UNIT

echo "==> Firewall (keep SSH open)"
ufw allow OpenSSH 2>/dev/null || true
ufw allow 39266/tcp comment 'SSH custom' 2>/dev/null || true
ufw allow "${PRIMARY_PORT}/udp" comment 'Hysteria2' || true
ufw allow "${PRIMARY_PORT}/tcp" comment 'Hysteria2 masquerade' || true
ufw allow "${HOP_PORT}/udp" comment 'Hysteria2 hop' || true
ufw --force enable || true

echo "==> Starting services"
systemctl daemon-reload
systemctl enable --now hysteria-server.service
systemctl enable --now hysteria-server-hop.service
sleep 2
systemctl --no-pager --full status hysteria-server.service | sed -n '1,15p' || true
systemctl --no-pager --full status hysteria-server-hop.service | sed -n '1,15p' || true

URI1="hysteria2://${HY2_AUTH}@${SERVER_IP}:${PRIMARY_PORT}?alpn=h3&insecure=1&obfs=salamander&obfs-password=${HY2_OBFS}&security=tls&sni=${SERVER_IP}#${NODE_NAME_PRIMARY}"
URI2="hysteria2://${HY2_AUTH}@${SERVER_IP}:${HOP_PORT}?alpn=h3&insecure=1&obfs=salamander&obfs-password=${HY2_OBFS}&security=tls&sni=${SERVER_IP}#${NODE_NAME_HOP}"

mkdir -p /root/hysteria-client
cat >/root/hysteria-client/uris.txt <<EOF
${URI1}
${URI2}
EOF
chmod 600 /root/hysteria-client/uris.txt

echo
echo "======== CLIENT URIs ========"
echo "$URI1"
echo "$URI2"
echo "Saved to /root/hysteria-client/uris.txt"
echo "============================="

if [[ -n "$GH_PAT" ]]; then
  echo "==> Updating GitHub subscription ${GH_REPO}"
  TMP=$(mktemp -d)
  git clone --depth 1 "https://x-access-token:${GH_PAT}@github.com/${GH_REPO}.git" "$TMP/repo"
  cd "$TMP/repo"
  DECODED="$(base64 -d sub.txt 2>/dev/null | sed '/^$/d' || true)"
  FILTERED="$(printf '%s\n' "$DECODED" | grep -v 'Япония' || true)"
  {
    printf '%s\n' "$FILTERED"
    printf '%s\n' "$URI1"
    printf '%s\n' "$URI2"
  } | sed '/^$/d' | base64 -w0 > sub.txt
  echo >> sub.txt

  cat > README.md <<'EOF'
# VPN subscription mirror

Подписка для Happ / v2rayN / Streisand / v2rayNG / Hiddify.

Сейчас в подписке **Hysteria2**:
- 🇩🇪 Германия — UDP 443 + hop UDP 20000
- 🇯🇵 Япония (Tokyo) — UDP 443 + hop UDP 20000

## Ссылка для клиента

```
https://raw.githubusercontent.com/maximf71/subscription_vpn/main/sub.txt#Мой-VPS
```

В Happ: **+ → Add subscription** → вставить ссылку выше → Update.
EOF

  git config user.name "hysteria-installer"
  git config user.email "installer@local"
  git add sub.txt README.md
  if git diff --cached --quiet; then
    echo "Subscription already up to date"
  else
    git commit -m "Add Japan Hysteria2 node (${SERVER_IP})"
    git push
    echo "GitHub subscription updated"
  fi
  rm -rf "$TMP"
else
  echo "GH_PAT not set — skip GitHub update. Paste URIs into sub.txt manually."
fi

echo
echo "Done. Happ subscription URL:"
echo "https://raw.githubusercontent.com/maximf71/subscription_vpn/main/sub.txt#Мой-VPS"
