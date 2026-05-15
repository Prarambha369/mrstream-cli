#!/bin/sh
# MrStream-Cli Installer

BIN_DIR="$HOME/.local/bin"
SHARE_DIR="$HOME/.local/share/mrstream"

mkdir -p "$BIN_DIR"
mkdir -p "$SHARE_DIR"

# Copy the main executable
cp mrstream "$BIN_DIR/mrstream"
chmod +x "$BIN_DIR/mrstream"

# Copy the src directory to the share directory
cp -r src "$SHARE_DIR/"

printf "✅ MrStream-Cli installed to %s/mrstream\n" "$BIN_DIR"
printf "✅ Source files copied to %s/src\n" "$SHARE_DIR"
printf "Make sure %s is in your PATH.\n" "$BIN_DIR"
