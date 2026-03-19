#!/usr/bin/env bash
set -euo pipefail

VERSION="1.2"

PROJECT_NAME="P-NATS"
BIN_NAME="P-NATS"

INSTALL_BIN_DIR="/usr/local/bin"
INSTALL_LIB_DIR="/usr/local/lib/${PROJECT_NAME}"
VENV_DIR="${INSTALL_LIB_DIR}/venv"
VENV_PYTHON="${VENV_DIR}/bin/python"
TARGET_SCRIPT="${INSTALL_LIB_DIR}/P-NATS.sh"

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

chmod_with_sudo_if_needed() {
  local mode="$1"
  local target="$2"

  if [[ -w "$target" ]] || [[ -w "$(dirname "$target")" ]]; then
    chmod "$mode" "$target"
  else
    sudo chmod "$mode" "$target"
  fi
}

remove_with_sudo_if_needed() {
  local target="$1"

  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -w "$(dirname "$target")" ]]; then
      rm -rf "$target"
    else
      sudo rm -rf "$target"
    fi
  fi
}

run_python_in_venv() {
  local -a args=("$@")

  if [[ -w "$INSTALL_LIB_DIR" ]]; then
    "$VENV_PYTHON" "${args[@]}"
  else
    sudo "$VENV_PYTHON" "${args[@]}"
  fi
}

create_venv() {
  echo "Creating Python virtual environment..."

  remove_with_sudo_if_needed "$VENV_DIR"

  if [[ -w "$INSTALL_LIB_DIR" ]]; then
    python3 -m venv "$VENV_DIR"
  else
    sudo python3 -m venv "$VENV_DIR"
  fi
}

venv_is_healthy() {
  [[ -x "$VENV_PYTHON" ]] || return 1
  "$VENV_PYTHON" -m pip --version >/dev/null 2>&1 || return 1
  return 0
}

repair_or_create_venv() {
  if venv_is_healthy; then
    echo "Using existing virtual environment..."
    return
  fi

  if [[ -d "$VENV_DIR" ]]; then
    echo "Existing virtual environment is broken or missing pip. Recreating..."
  else
    echo "Virtual environment not found."
  fi

  create_venv

  if ! "$VENV_PYTHON" -m pip --version >/dev/null 2>&1; then
    echo "pip not found in venv. Trying ensurepip..."
    run_python_in_venv -m ensurepip --upgrade
  fi

  if ! "$VENV_PYTHON" -m pip --version >/dev/null 2>&1; then
    echo "[ERROR] Failed to initialize pip in the virtual environment." >&2
    echo "[ERROR] Please make sure python3-venv is installed on your system." >&2
    exit 1
  fi
}

mkdir_with_sudo_if_needed "$INSTALL_LIB_DIR"

echo "Copying program files..."
copy_with_sudo_if_needed "bin/P-NATS.sh" "$TARGET_SCRIPT"
chmod_with_sudo_if_needed +x "$TARGET_SCRIPT"

repair_or_create_venv

echo "Upgrading pip..."
run_python_in_venv -m pip install --upgrade pip

echo "Installing Python dependency: gemmi"
run_python_in_venv -m pip install gemmi

echo "Installing executable..."
if [[ -w "$INSTALL_BIN_DIR" ]]; then
  ln -sf "$TARGET_SCRIPT" "${INSTALL_BIN_DIR}/${BIN_NAME}"
else
  sudo ln -sf "$TARGET_SCRIPT" "${INSTALL_BIN_DIR}/${BIN_NAME}"
fi

echo ""
echo "Executable: ${INSTALL_BIN_DIR}/${BIN_NAME}"
echo ""
echo "${PROJECT_NAME} ${VERSION} was installed successfully."
