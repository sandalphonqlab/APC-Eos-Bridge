#!/bin/bash

# ============================================================

# APC mk2 / Eos Bridge - iPad PWA Installer

# ============================================================

RED=’\033[0;31m’
GREEN=’\033[0;32m’
YELLOW=’\033[1;33m’
CYAN=’\033[0;36m’
ORANGE=’\033[0;33m’
WHITE=’\033[1;37m’
DIM=’\033[2m’
NC=’\033[0m’
BOLD=’\033[1m’

clear
echo “”
echo -e “${ORANGE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}”
echo -e “${ORANGE}${BOLD}║       APC mk2 / Eos Bridge  —  iPad PWA Installer           ║${NC}”
echo -e “${ORANGE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}”
echo “”
echo -e “${DIM}  This installer sets up the iPad Progressive Web App.”
echo -e “  It copies the PWA files, starts an HTTP server, and”
echo -e “  optionally configures auto-start on boot.${NC}”
echo “”
echo -e “${YELLOW}  Press Enter to begin or Ctrl+C to cancel…${NC}”
read

# ── Helpers ──────────────────────────────────────────────────

ask() {
local prompt=”$1” default=”$2” varname=”$3”
echo -e “${CYAN}${prompt}${NC}”
[ -n “$default” ] && echo -e “${DIM}  Default: ${default}${NC}”
read -p “  > “ input
[ -z “$input” ] && input=”$default”
eval “$varname="$input"”
}

ask_yn() {
local prompt=”$1” default=”$2” varname=”$3”
while true; do
echo -e “${CYAN}${prompt} [y/n]${NC}”
[ -n “$default” ] && echo -e “${DIM}  Default: ${default}${NC}”
read -p “  > “ input
[ -z “$input” ] && input=”$default”
case “$input” in
[Yy]*) eval “$varname=yes”; break ;;
[Nn]*) eval “$varname=no”;  break ;;
*) echo -e “${RED}  Please answer y or n${NC}” ;;
esac
done
}

step()  { echo “”; echo -e “${ORANGE}${BOLD}── $1 ──────────────────────────────────────────────${NC}”; }
ok()    { echo -e “${GREEN}  ✓ $1${NC}”; }
warn()  { echo -e “${YELLOW}  ⚠ $1${NC}”; }
fail()  { echo -e “${RED}  ✗ $1${NC}”; }
info()  { echo -e “${DIM}  $1${NC}”; }

# ── Check PWA files exist next to installer ──────────────────

SCRIPT_DIR=”$(cd “$(dirname “$0”)” && pwd)”
REQUIRED_FILES=(“eos_apc_editor.html” “manifest.json” “sw.js” “icon-192.png” “icon-512.png”)
MISSING=()

step “Checking PWA files”
for f in “${REQUIRED_FILES[@]}”; do
if [ -f “$SCRIPT_DIR/$f” ]; then
ok “Found $f”
else
fail “Missing $f”
MISSING+=(”$f”)
fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
echo “”
echo -e “${RED}  The following files are missing from the installer directory:${NC}”
for f in “${MISSING[@]}”; do
echo -e “${RED}    - $f${NC}”
done
echo “”
echo -e “${YELLOW}  All five PWA files must be in the same folder as this installer.${NC}”
exit 1
fi

# ── Gather config ─────────────────────────────────────────────

step “STEP 1 — Install Location”
CURRENT_USER=$(whoami)
CURRENT_HOME=$(eval echo ~$CURRENT_USER)
echo -e “  Detected user: ${WHITE}${CURRENT_USER}${NC}”
echo “”
ask “Where should the PWA files be installed?” “$CURRENT_HOME/Documents/apc-pwa” INSTALL_DIR

step “STEP 2 — HTTP Server Port”
echo -e “${DIM}  The iPad connects to this port to load the app.”
echo -e “  Make sure this port is not used by anything else.${NC}”
echo “”
ask “HTTP server port:” “8080” SERVE_PORT

step “STEP 3 — Auto-start”
echo -e “${DIM}  Creates a launch agent so the HTTP server starts automatically”
echo -e “  when the Mac boots. Without this you must start it manually.${NC}”
echo “”
ask_yn “Start HTTP server automatically on boot?” “y” SETUP_AUTOSTART

# ── Detect Mac IP ─────────────────────────────────────────────

MAC_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo “2.0.0.2”)

# ── Summary ───────────────────────────────────────────────────

echo “”
echo -e “${ORANGE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}”
echo -e “${ORANGE}${BOLD}║                  CONFIGURATION SUMMARY                      ║${NC}”
echo -e “${ORANGE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}”
echo “”
echo -e “  ${WHITE}Install directory:${NC}  $INSTALL_DIR”
echo -e “  ${WHITE}HTTP port:${NC}          $SERVE_PORT”
echo -e “  ${WHITE}Mac IP (detected):${NC}  $MAC_IP”
echo -e “  ${WHITE}iPad URL will be:${NC}   ${GREEN}http://$MAC_IP:$SERVE_PORT/eos_apc_editor.html${NC}”
echo -e “  ${WHITE}Auto-start:${NC}         $SETUP_AUTOSTART”
echo “”
ask_yn “Proceed with installation?” “y” PROCEED
[ “$PROCEED” = “no” ] && echo “” && echo -e “${YELLOW}Cancelled.${NC}” && exit 0

# ── Install ───────────────────────────────────────────────────

step “Installing — Copying PWA files”
mkdir -p “$INSTALL_DIR”
for f in “${REQUIRED_FILES[@]}”; do
cp “$SCRIPT_DIR/$f” “$INSTALL_DIR/$f”
ok “Copied $f”
done

step “Installing — Verifying files”
for f in “${REQUIRED_FILES[@]}”; do
if [ -f “$INSTALL_DIR/$f” ]; then
ok “$INSTALL_DIR/$f”
else
fail “Failed to copy $f”
exit 1
fi
done

if [ “$SETUP_AUTOSTART” = “yes” ]; then
step “Installing — Creating HTTP server launch agent”
PLIST_PATH=”$CURRENT_HOME/Library/LaunchAgents/com.eos.apcpwa.plist”
LOG_PATH=”$INSTALL_DIR/pwa_server.log”

```
cat > "$PLIST_PATH" << ENDPLIST
```

<?xml version="1.0" encoding="UTF-8"?>

<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">

<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.eos.apcpwa</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>-m</string>
        <string>http.server</string>
        <string>$SERVE_PORT</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_PATH</string>
    <key>StandardErrorPath</key>
    <string>$LOG_PATH</string>
</dict>
</plist>
ENDPLIST
    ok "Written $PLIST_PATH"

```
# Unload if already running
launchctl unload "$PLIST_PATH" 2>/dev/null

launchctl load "$PLIST_PATH"
if [ $? -eq 0 ]; then
    ok "HTTP server started on port $SERVE_PORT"
else
    warn "Could not load launch agent — start manually with:"
    info "cd $INSTALL_DIR && python3 -m http.server $SERVE_PORT"
fi
```

fi

# ── Add serveapp alias ────────────────────────────────────────

step “Installing — Adding serveapp alias”
SHELL_RC=”$CURRENT_HOME/.zshrc”
[ -f “$CURRENT_HOME/.bash_profile” ] && [ ! -f “$CURRENT_HOME/.zshrc” ] && SHELL_RC=”$CURRENT_HOME/.bash_profile”

START_CMD=“cd $INSTALL_DIR && python3 -m http.server $SERVE_PORT”
STOP_CMD=“launchctl unload $CURRENT_HOME/Library/LaunchAgents/com.eos.apcpwa.plist 2>/dev/null || pkill -f ‘http.server $SERVE_PORT’”
ALIAS_LINE=“alias serveapp="$START_CMD"”

if grep -q “serveapp” “$SHELL_RC” 2>/dev/null; then
warn “serveapp alias already exists — skipping”
else
echo “$ALIAS_LINE” >> “$SHELL_RC”
ok “Added serveapp alias to $SHELL_RC”
fi

# ── Test server ───────────────────────────────────────────────

step “Verifying — Testing HTTP server”
sleep 1
HTTP_RESPONSE=$(curl -s -o /dev/null -w “%{http_code}” “http://127.0.0.1:$SERVE_PORT/eos_apc_editor.html” 2>/dev/null)
if [ “$HTTP_RESPONSE” = “200” ]; then
ok “HTTP server responding correctly (HTTP 200)”
else
warn “Server not yet responding (got $HTTP_RESPONSE) — may need a moment to start”
warn “Try: curl -I http://127.0.0.1:$SERVE_PORT/eos_apc_editor.html”
fi

# ── Final instructions ────────────────────────────────────────

echo “”
echo -e “${ORANGE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}”
echo -e “${ORANGE}${BOLD}║               INSTALLATION COMPLETE                         ║${NC}”
echo -e “${ORANGE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}”
echo “”
echo -e “${GREEN}  Files installed to:${NC}  $INSTALL_DIR”
echo -e “${GREEN}  Server port:${NC}          $SERVE_PORT”
echo “”
echo -e “${ORANGE}${BOLD}  NOW INSTALL ON THE IPAD:${NC}”
echo “”
echo -e “  1. Make sure the iPad is on the ${WHITE}same WiFi network${NC} as this Mac”
echo “”
echo -e “  2. Open ${WHITE}Safari${NC} on the iPad and go to:”
echo -e “     ${GREEN}${BOLD}http://$MAC_IP:$SERVE_PORT/eos_apc_editor.html${NC}”
echo “”
echo -e “  3. Tap the ${WHITE}Share button${NC} (box with upward arrow)”
echo “”
echo -e “  4. Tap ${WHITE}Add to Home Screen${NC}”
echo “”
echo -e “  5. Name it ${WHITE}APC EOS${NC} and tap ${WHITE}Add${NC}”
echo “”
echo -e “  6. The app icon appears on the iPad home screen.”
echo -e “     Tap it to open full screen.”
echo “”
echo -e “${DIM}  Note: The Python bridge (eos_apc_feedback.py) must also be”
echo -e “  running on this Mac for live Eos status and OSC firing to work.${NC}”
echo “”
echo -e “${DIM}  To start server manually if needed:${NC}”
echo -e “  ${DIM}cd $INSTALL_DIR && python3 -m http.server $SERVE_PORT${NC}”
echo “”
ENDOFSCRIPT