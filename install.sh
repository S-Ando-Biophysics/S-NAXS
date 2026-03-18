#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0"

PROJECT_NAME="P-NATS"
BIN_NAME="P-NATS"

INSTALL_BIN_DIR="/usr/local/bin"
INSTALL_LIB_DIR="/usr/local/lib/${PROJECT_NAME}"

echo ""
echo "Installing ${PROJECT_NAME} ${VERSION}..."
echo ""

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Required command not found: $1" >&2
    exit 1
  }
}

need_cmd python3

mkdir_with_sudo_if_needed() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    return
  fi

  if [[ -w "$(dirname "$dir")" ]]; then
    mkdir -p "$dir"
  else
    sudo mkdir -p "$dir"
  fi
}

copy_with_sudo_if_needed() {
  local src="$1"
  local dst="$2"

  if [[ -w "$(dirname "$dst")" ]]; then
    cp "$src" "$dst"
  else
    sudo cp "$src" "$dst"
  fi
}

run_in_target_venv() {
  local cmd="$1"

  if [[ -w "$INSTALL_LIB_DIR" ]]; then
    bash -lc "$cmd"
  else
    sudo bash -lc "$cmd"
  fi
}

mkdir_with_sudo_if_needed "$INSTALL_LIB_DIR"

echo "Copying program files..."
copy_with_sudo_if_needed "bin/P-NATS.sh" "${INSTALL_LIB_DIR}/P-NATS.sh"

if [[ -w "$INSTALL_LIB_DIR" ]]; then
  chmod +x "${INSTALL_LIB_DIR}/P-NATS.sh"
else
  sudo chmod +x "${INSTALL_LIB_DIR}/P-NATS.sh"
fi

if [[ ! -d "${INSTALL_LIB_DIR}/venv" ]]; then
  echo "Creating Python virtual environment..."
  if [[ -w "$INSTALL_LIB_DIR" ]]; then
    python3 -m venv "${INSTALL_LIB_DIR}/venv"
  else
    sudo python3 -m venv "${INSTALL_LIB_DIR}/venv"
  fi
else
  echo "Using existing virtual environment..."
fi

echo "Installing Python dependency: gemmi"
if [[ -w "$INSTALL_LIB_DIR" ]]; then
  "${INSTALL_LIB_DIR}/venv/bin/python" -m pip install --upgrade pip
  "${INSTALL_LIB_DIR}/venv/bin/python" -m pip install gemmi
else
  sudo "${INSTALL_LIB_DIR}/venv/bin/python" -m pip install --upgrade pip
  sudo "${INSTALL_LIB_DIR}/venv/bin/python" -m pip install gemmi
fi

echo "Installing executable..."
if [[ -w "$INSTALL_BIN_DIR" ]]; then
  ln -sf "${INSTALL_LIB_DIR}/P-NATS.sh" "${INSTALL_BIN_DIR}/${BIN_NAME}"
else
  sudo ln -sf "${INSTALL_LIB_DIR}/P-NATS.sh" "${INSTALL_BIN_DIR}/${BIN_NAME}"
fi

echo ""
echo "${PROJECT_NAME} ${VERSION} was installed successfully."
echo ""
echo "Executable: ${INSTALL_BIN_DIR}/${BIN_NAME}"
