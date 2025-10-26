#!/usr/bin/env bash

# --- Configuration ---
SCRIPT_DIR="$(cd ../"$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo ${SCRIPT_DIR}
SCRIPT_NAME="miro-docker.sh"
LAUNCHER_NAME="miro-hub"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/$LAUNCHER_NAME"

# --- Ensure ~/.local/bin exists ---
mkdir -p "$INSTALL_DIR"

# --- Create the launcher ---
cat > "$INSTALL_PATH" << EOF
#!/usr/bin/env bash
# Auto-generated launcher for MiRo Docker helper
cd "$SCRIPT_DIR" || { echo "❌ Failed to cd into script directory"; exit 1; }
exec "$SCRIPT_DIR/$SCRIPT_NAME" "\$@"
EOF

# --- Make it executable ---
chmod +x "$INSTALL_PATH"

# --- Inform the user ---
echo "✅ Launcher '$LAUNCHER_NAME' installed at $INSTALL_PATH"
echo "It points to the script $SCRIPT_NAME in: $SCRIPT_DIR"

# --- Check if ~/.local/bin is in PATH ---
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    echo "⚠️ $INSTALL_DIR is not in your PATH."
    echo "Add the following line to your shell config (~/.bashrc, ~/.zshrc, etc.):"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo "You can now run '$LAUNCHER_NAME start' from anywhere."
