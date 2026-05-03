#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"

# Copy binary
cp mrstream "$INSTALL_DIR/mrstream"
chmod +x "$INSTALL_DIR/mrstream"

# Copy source structure to a permanent location (e.g., ~/.local/share/mrstream)
SHARE_DIR="${HOME}/.local/share/mrstream"
mkdir -p "$SHARE_DIR/src/core" "$SHARE_DIR/src/plugins"
cp src/core/*.sh "$SHARE_DIR/src/core/"
cp src/plugins/*.sh "$SHARE_DIR/src/plugins/"

# Patch mrstream to use SHARE_DIR
sed -i "s|\. src/|. $SHARE_DIR/src/|g" "$INSTALL_DIR/mrstream"

printf "✅ MrStream-Cli installed to %s/mrstream\n" "$INSTALL_DIR"
printf "Make sure %s is in your PATH.\n" "$INSTALL_DIR"
