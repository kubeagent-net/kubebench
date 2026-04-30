#!/usr/bin/env bash
# kubebench install script — detects OS, installs requirements, and installs kubebench to PATH
# Usage: curl -fsSL https://raw.githubusercontent.com/kubeagent-net/kubebench/main/install.sh | bash
set -euo pipefail

KUBEBENCH_REPO="https://github.com/kubeagent-net/kubebench.git"
KUBEBENCH_INSTALL_DIR="/opt/kubebench"
KUBEBENCH_BIN="/usr/local/bin/kubebench"

# --- helpers ---
info()  { echo "[INFO]  $*"; }
ok()    { echo "[OK]    $*"; }
warn()  { echo "[WARN]  $*"; }
die()   { echo "[ERROR] $*" >&2; exit 1; }

has() { command -v "$1" &>/dev/null; }

maybe_sudo() {
  if [ "$(id -u)" = "0" ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# --- detect OS ---
OS=""
PKG=""
case "$(uname -s)" in
  Darwin)
    OS="macos"
    has brew || die "Homebrew is required on macOS. Install it from https://brew.sh"
    PKG="brew install"
    ;;
  Linux)
    OS="linux"
    if has apt-get; then
      PKG="maybe_sudo apt-get install -y"
      maybe_sudo apt-get update -qq
    elif has dnf; then
      PKG="maybe_sudo dnf install -y"
    elif has yum; then
      PKG="maybe_sudo yum install -y"
    elif has pacman; then
      PKG="maybe_sudo pacman -Sy --noconfirm"
    elif has apk; then
      PKG="maybe_sudo apk add --no-cache"
    else
      die "Unsupported Linux distribution — please install dependencies manually."
    fi
    ;;
  *)
    die "Unsupported OS: $(uname -s)"
    ;;
esac

info "Detected OS: $OS"

# --- install git (needed to clone kubebench) ---
if has git; then
  ok "git already installed"
else
  info "Installing git..."
  $PKG git
  ok "git installed"
fi

# --- install jq ---
if has jq; then
  ok "jq already installed ($(jq --version))"
else
  info "Installing jq..."
  $PKG jq
  ok "jq installed"
fi

# --- install docker ---
if has docker; then
  ok "Docker already installed ($(docker --version | head -1))"
else
  info "Installing Docker..."
  if [ "$OS" = "macos" ]; then
    brew install --cask docker
    warn "Docker Desktop installed. Please start it before running kubebench."
  elif has apt-get; then
    curl -fsSL https://get.docker.com | maybe_sudo sh
    if [ "$(id -u)" != "0" ]; then
      sudo usermod -aG docker "$USER" 2>/dev/null || true
      warn "Docker installed. You may need to log out and back in for group membership to take effect."
    fi
  else
    $PKG docker
    maybe_sudo systemctl enable --now docker 2>/dev/null || true
  fi
  ok "Docker installed"
fi

# --- install kubectl ---
if has kubectl; then
  ok "kubectl already installed ($(kubectl version --client --short 2>/dev/null || kubectl version --client | head -1))"
else
  info "Installing kubectl..."
  if [ "$OS" = "macos" ]; then
    brew install kubectl
  else
    KUBE_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    ARCH=$(uname -m); [ "$ARCH" = "aarch64" ] && ARCH="arm64" || ARCH="amd64"
    KUBE_URL="https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kubectl"
    tmp_kube=$(mktemp)
    curl -fsSL "$KUBE_URL" -o "$tmp_kube"
    expected_sum=$(curl -fsSL "${KUBE_URL}.sha256")
    echo "${expected_sum}  ${tmp_kube}" | sha256sum -c - || {
      rm -f "$tmp_kube"
      die "kubectl checksum mismatch — aborting"
    }
    maybe_sudo install -m 0755 "$tmp_kube" /usr/local/bin/kubectl
    rm -f "$tmp_kube"
  fi
  ok "kubectl installed"
fi

# --- install k3d ---
if has k3d; then
  ok "k3d already installed ($(k3d version | head -1))"
else
  info "Installing k3d..."
  if [ "$OS" = "macos" ]; then
    brew install k3d
  else
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  fi
  ok "k3d installed"
fi

# --- install kubebench ---
info "Installing kubebench..."
if [ -d "$KUBEBENCH_INSTALL_DIR/.git" ]; then
  info "Updating existing kubebench install at $KUBEBENCH_INSTALL_DIR..."
  git -C "$KUBEBENCH_INSTALL_DIR" pull --ff-only
else
  maybe_sudo git clone "$KUBEBENCH_REPO" "$KUBEBENCH_INSTALL_DIR"
  maybe_sudo chmod +x "$KUBEBENCH_INSTALL_DIR/kubebench.sh"
fi

# Create kubebench wrapper in /usr/local/bin
maybe_sudo tee "$KUBEBENCH_BIN" > /dev/null <<EOF
#!/usr/bin/env bash
exec "$KUBEBENCH_INSTALL_DIR/kubebench.sh" "\$@"
EOF
maybe_sudo chmod +x "$KUBEBENCH_BIN"
ok "kubebench installed → $KUBEBENCH_BIN"

# --- verify ---
echo ""
info "Verifying requirements..."
MISSING=0
for cmd in jq docker kubectl k3d kubebench; do
  if has "$cmd"; then
    ok "  $cmd"
  else
    warn "  $cmd — NOT FOUND"
    MISSING=$((MISSING + 1))
  fi
done

echo ""
if [ "$MISSING" -eq 0 ]; then
  ok "All done. Run: kubebench --help"
else
  warn "$MISSING requirement(s) not in PATH. Check the errors above."
fi
