#!/usr/bin/bash
set -xeuo pipefail

extract() {
  if [[ "$RUNNER_OS" == "Windows" ]]; then
    unzip -v "$1"
  else
    tar -vzxf "$1"
  fi
}

set_executable() {
  if [[ "$RUNNER_OS" == "Windows" ]]; then
    return 0
  else
    chmod u+x "$1"
  fi
}

if [[ "$RUNNER_OS" == "Windows" && "$RUNNER_ARCH" == "X64" ]]; then
  FILENAME="nvim-win64"
  SUFFIX=".zip"
elif [[ "$RUNNER_OS" == "Linux" && "$RUNNER_ARCH" == "X64" ]]; then
  FILENAME="nvim-linux-x86_64"
  SUFFIX=".tar.gz"
elif [[ "$RUNNER_OS" == "Linux" && "$RUNNER_ARCH" == "ARM64" ]]; then
  FILENAME="nvim-linux-arm64"
  SUFFIX=".tar.gz"
elif [[ "$RUNNER_OS" == "macOS" && "$RUNNER_ARCH" == "X64" ]]; then
  FILENAME="nvim-macos-x86_64"
  SUFFIX=".tar.gz"
elif [[ "$RUNNER_OS" == "macOS" && "$RUNNER_ARCH" == "ARM64" ]]; then
  FILENAME="nvim-macos-arm64"
  SUFFIX=".tar.gz"
else
  echo "Not supported $RUNNER_ARCH $RUNNER_OS"
  exit 1
fi

URL="https://github.com/neovim/neovim/releases/latest/download/${FILENAME}${SUFFIX}"
OUTPUT_DIR="${HOME}/nvim-${GITHUB_RUN_ID}"

mkdir -p "$OUTPUT_DIR"
curl -Lo "${OUTPUT_DIR}/${FILENAME}${SUFFIX}" "$URL"

cd "$OUTPUT_DIR"
extract "${FILENAME}${SUFFIX}"
# The files were archived with a leading directory
set_executable "${FILENAME}/bin/nvim"

echo "${OUTPUT_DIR}/${FILENAME}/bin" >>"$GITHUB_PATH"
