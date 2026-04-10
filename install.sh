#!/usr/bin/env bash
# kubebench install script — detects OS and installs all requirements
# Usage: curl -fsSL https://raw.githubusercontent.com/your-org/kubebench/main/install.sh | bash
set -euo pipefail

# --- helpers ---
info()  { echo "[INFO]  $*"; }
ok()    { echo "[OK]    $*"; }
warn()  { echo "[WARN]  $*"; }
die()   { echo "[ERROR] $*" >&2; exit 1; }

has() { command -v "$1" &>/dev/null; }

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
      PKG="sudo apt-get install -y"
      sudo apt-get update -qq
    elif has dnf; then
      PKG="sudo dnf install -y"
    elif has yum; then
      PKG="sudo yum install -y"
    elif has pacman; then
      PKG="sudo pacman -Sy --noconfirm"
    elif has apk; then
      PKG="sudo apk add --no-cache"
    else
      die "Unsupported Linux distribution — please install dependencies manually."
    fi
    ;;
  *)
    die "Unsupported OS: $(uname -s)"
    ;;
esac

info "Detected OS: $OS"

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
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER" 2>/dev/null || true
    warn "Docker installed. You may need to log out and back in for group membership to take effect."
  else
    $PKG docker
    sudo systemctl enable --now docker 2>/dev/null || true
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
    local_bin="$HOME/.local/bin"
    mkdir -p "$local_bin"
    KUBE_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    curl -fsSL "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/amd64/kubectl" -o "$local_bin/kubectl"
    chmod +x "$local_bin/kubectl"
    if [[ ":$PATH:" != *":$local_bin:"* ]]; then
      warn "Add $local_bin to your PATH: export PATH=\"\$PATH:$local_bin\""
    fi
  fi
  ok "kubectl installed"
fi

# --- install k3d (default cluster provider) ---
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

# --- verify ---
echo ""
info "Verifying requirements..."
MISSING=0
for cmd in jq docker kubectl k3d; do
  if has "$cmd"; then
    ok "  $cmd"
  else
    warn "  $cmd — NOT FOUND (may need to restart shell or start Docker)"
    MISSING=$((MISSING + 1))
  fi
done

echo ""
if [ "$MISSING" -eq 0 ]; then
  ok "All requirements satisfied. Run ./kubebench.sh --help to get started."
else
  warn "$MISSING requirement(s) not yet in PATH. Restart your shell and re-run this script to verify."
fi
