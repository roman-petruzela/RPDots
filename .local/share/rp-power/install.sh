#!/usr/bin/env bash
# rp-power — root half. Run with sudo.
# Installs the privileged helper, a scoped sudoers rule, a udev rule on AC
# state and a oneshot unit that reapplies the mode. See README "Power modes".
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

install -Dm755 "$SRC/rp-power-apply" /usr/local/bin/rp-power-apply

# sudoers — scoped to this one binary, nothing else
cat > /etc/sudoers.d/rp-power <<'EOF'
roman ALL=(root) NOPASSWD: /usr/local/bin/rp-power-apply
EOF
chmod 0440 /etc/sudoers.d/rp-power
visudo -cf /etc/sudoers.d/rp-power

# systemd oneshot that applies the mode for the current AC state
cat > /etc/systemd/system/rp-power-auto.service <<'EOF'
[Unit]
Description=Apply RPRice power mode for current AC state
After=tlp.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rp-power-apply auto

[Install]
WantedBy=multi-user.target
EOF

# udev — fire the oneshot when AC is plugged / unplugged
cat > /etc/udev/rules.d/99-rp-power.rules <<'EOF'
SUBSYSTEM=="power_supply", KERNEL=="ACAD", RUN+="/usr/bin/systemctl --no-block start rp-power-auto.service"
EOF

systemctl daemon-reload
systemctl enable rp-power-auto.service
udevadm control --reload-rules

mkdir -p /var/lib/rp-power
echo balanced > /var/lib/rp-power/mode

echo
echo "Done. Try:  rp-power status"
