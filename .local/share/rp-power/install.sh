#!/usr/bin/env bash
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

install -Dm755 "$SRC/rp-power-apply" /usr/local/bin/rp-power-apply

TARGET_USER="${SUDO_USER:?run through sudo so the target user is known}"
cat > /etc/sudoers.d/rp-power <<EOF
$TARGET_USER ALL=(root) NOPASSWD: /usr/local/bin/rp-power-apply
EOF
chmod 0440 /etc/sudoers.d/rp-power
visudo -cf /etc/sudoers.d/rp-power

cat > /etc/systemd/system/rp-power-auto.service <<'EOF'
[Unit]
Description=Apply RPRice power mode for current AC state

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rp-power-apply auto

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/udev/rules.d/99-rp-power.rules <<'EOF'
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="/usr/bin/systemctl --no-block start rp-power-auto.service"
EOF

cat > /etc/systemd/system/rp-power-gpu-guard.service <<'EOF'
[Unit]
Description=Re-assert RPRice dGPU power limit for current mode

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rp-power-apply auto
EOF

cat > /etc/systemd/system/rp-power-gpu-guard.timer <<'EOF'
[Unit]
Description=Periodic re-assert of RPRice dGPU power limit

[Timer]
OnBootSec=2min
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable rp-power-auto.service
systemctl enable --now rp-power-gpu-guard.timer
udevadm control --reload-rules

mkdir -p /var/lib/rp-power
echo balanced > /var/lib/rp-power/mode

echo
echo "Done. Try:  rp-power status"
