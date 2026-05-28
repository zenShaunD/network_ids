#!/usr/bin/env bash
# ============================================================
# Script  : install.sh
# Purpose : Install network_ids dependencies correctly on
#           Ubuntu 26.04 "Resolute" (and Debian-family).
#
#           Fixes:
#           - wireless-tools obsolete on 26.04 (replaced by iw)
#           - scapy/python-nmap missing for root (sudo python3)
#             because pip installed to user site-packages only
#           - netifaces / numpy available as system packages
#
# Usage   : sudo ./install.sh
# ============================================================
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "ERROR: run as root: sudo $0"; exit 1; }

INVOKING_USER="${SUDO_USER:-${USER}}"
USER_HOME="$(getent passwd "${INVOKING_USER}" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> [network_ids] Installing system dependencies..."
apt-get update -qq

# wireless-tools was dropped in Ubuntu 26.04 (resolute).
# Its functionality is fully covered by iw + iproute2.
# wpasupplicant provides the wireless scan/connect surface.
SYS_PKGS=(
  python3
  python3-pip
  python3-venv
  python3-dev
  nmap
  iw
  iproute2
  net-tools
  libpcap-dev
  tcpdump
  wpasupplicant
  python3-netifaces
  python3-numpy
  python3-requests
  python3-psutil
)

apt-get install -y "${SYS_PKGS[@]}"
echo "==> System packages installed"

# ──────────────────────────────────────────────────────────────
# Install Python packages into a venv at ./venv
# Running network_ids.py as root via: sudo ./run.sh
# avoids the user-vs-root site-packages split entirely.
# ──────────────────────────────────────────────────────────────
VENV_DIR="${SCRIPT_DIR}/venv"

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "==> Creating venv at ${VENV_DIR}..."
  python3 -m venv --system-site-packages "${VENV_DIR}"
else
  echo "==> venv already exists at ${VENV_DIR}"
fi

echo "==> Installing Python deps into venv..."
"${VENV_DIR}/bin/pip" install --upgrade pip --quiet
"${VENV_DIR}/bin/pip" install -r "${SCRIPT_DIR}/requirements.txt" --quiet

echo "==> Creating run wrapper: ${SCRIPT_DIR}/run.sh"
cat > "${SCRIPT_DIR}/run.sh" <<RUNSH
#!/usr/bin/env bash
# Wrapper: runs network_ids.py with the correct venv under sudo.
# Usage: sudo ./run.sh [args...]
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec sudo "\${SCRIPT_DIR}/venv/bin/python3" "\${SCRIPT_DIR}/network_ids.py" "\$@"
RUNSH
chmod +x "${SCRIPT_DIR}/run.sh"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  network_ids install complete                        ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Run:  sudo ./run.sh                                 ║"
echo "║  Or:   sudo ${VENV_DIR}/bin/python3 network_ids.py   ║"
echo "║                                                      ║"
echo "║  wireless-tools replaced by: iw + iproute2           ║"
echo "║  scapy: installed in venv (root-safe)                ║"
echo "╚══════════════════════════════════════════════════════╝"
