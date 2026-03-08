#!/usr/bin/env sh
set -eu

PREFIX=${PREFIX:-"$HOME/.local"}
BIN_DIR="$PREFIX/bin"
REPO=${REPO:-"julian0xff/clipcopy"}
REF=${REF:-"main"}
CLIPCOPY_RAW_URL=${CLIPCOPY_RAW_URL:-"https://raw.githubusercontent.com/$REPO/$REF/clipcopy"}
TARGET="$BIN_DIR/clipcopy"

# Only use local source when install.sh was invoked directly from disk
LOCAL_SOURCE=""
case "$0" in
  *install.sh)
    SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
    if [ -f "$SCRIPT_DIR/clipcopy" ]; then
      LOCAL_SOURCE="$SCRIPT_DIR/clipcopy"
    fi
    ;;
esac

mkdir -p "$BIN_DIR"

install_from_local() {
  install -m 755 "$LOCAL_SOURCE" "$TARGET"
}

download_with_curl_or_wget() {
  tmp_file=$1

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$CLIPCOPY_RAW_URL" -o "$tmp_file"
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp_file" "$CLIPCOPY_RAW_URL"
    return 0
  fi

  echo "Need curl or wget to download clipcopy from $CLIPCOPY_RAW_URL" >&2
  return 1
}

install_from_remote() {
  tmp_file=$(mktemp -t clipcopy.XXXXXX)
  trap 'rm -f "$tmp_file"' EXIT HUP INT TERM

  download_with_curl_or_wget "$tmp_file"
  install -m 755 "$tmp_file" "$TARGET"
}

if [ -n "$LOCAL_SOURCE" ]; then
  install_from_local
else
  install_from_remote
fi

echo "Installed clipcopy to $TARGET"
echo "Make sure $BIN_DIR is in your PATH."
