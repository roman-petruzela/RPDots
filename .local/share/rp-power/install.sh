#!/usr/bin/env bash
# rp-power — root half. Run with sudo.
# Installs the privileged helper, a scoped sudoers rule, a udev rule on AC
# state, a oneshot unit that reapplies the mode, and a timer that re-asserts
# the dGPU power limit periodically. See README "Power modes".
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

install -Dm755 "$SRC/rp-power-apply" /usr/local/bin/rp-power-apply

# sudoers — scoped to this one binary, nothing else, for the user who ran sudo
TARGET_USER="${SUDO_USER:?run through sudo so the target user is known}"
cat > /etc/sudoers.d/rp-power <<EOF
$TARGET_USER ALL=(root) NOPASSWD: /usr/local/bin/rp-power-apply
EOF
chmod 0440 /etc/sudoers.d/rp-power
visudo -cf /etc/sudoers.d/rp-power

# systemd oneshot that applies the mode for the current AC state.
# No After=tlp.service here on purpose — tlp.service on this box is itself
# ordered After=multi-user.target, so combining that with our own
# WantedBy=multi-user.target created an ordering cycle that systemd broke
# arbitrarily on every boot (visible as "Found ordering cycle" in the journal).
cat > /etc/systemd/system/rp-power-auto.service <<'EOF'
[Unit]
Description=Apply RPRice power mode for current AC state

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

# nvidia-smi power-limit/clock-lock settings don't survive the dGPU going
# through a runtime suspend/resume cycle — the driver resets to its own
# default limit on wake. The AC-event oneshot above only re-asserts on plug
# change, so a dGPU that wakes up mid-session (browser, game...) while
# nothing else changed would silently sit at the driver default instead of
# the mode's limit. This timer re-runs the idempotent "auto" apply regularly;
# it's a no-op whenever the dGPU is suspended (see dgpu_suspended in
# rp-power-apply), so it never wakes it just to check.
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
