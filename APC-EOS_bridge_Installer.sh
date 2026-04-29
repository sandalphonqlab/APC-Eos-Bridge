#!/bin/bash

# ============================================================

# APC mk2 / Eos Bridge - Interactive Installer

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
echo -e “${ORANGE}${BOLD}║       APC mk2 / Eos Bridge  —  Interactive Installer         ║${NC}”
echo -e “${ORANGE}${BOLD}║                          v16.0                               ║${NC}”
echo -e “${ORANGE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}”
echo “”
echo -e “${DIM}This installer will configure and deploy the APC mk2 / Eos bridge”
echo -e “on this Mac. It will ask for your network settings, install Python”
echo -e “dependencies, write all required files and set up auto-start.${NC}”
echo “”
echo -e “${YELLOW}Press Enter to begin or Ctrl+C to cancel…${NC}”
read

# ── Helper functions ─────────────────────────────────────────

ask() {
local prompt=”$1”
local default=”$2”
local varname=”$3”
echo -e “${CYAN}${prompt}${NC}”
if [ -n “$default” ]; then
echo -e “${DIM}  Default: ${default}${NC}”
fi
read -p “  > “ input
if [ -z “$input” ] && [ -n “$default” ]; then
input=”$default”
fi
eval “$varname="$input"”
}

ask_yn() {
local prompt=”$1”
local default=”$2”
local varname=”$3”
while true; do
echo -e “${CYAN}${prompt} [y/n]${NC}”
if [ -n “$default” ]; then
echo -e “${DIM}  Default: ${default}${NC}”
fi
read -p “  > “ input
if [ -z “$input” ]; then
input=”$default”
fi
case “$input” in
[Yy]*) eval “$varname=yes”; break ;;
[Nn]*) eval “$varname=no”; break ;;
*) echo -e “${RED}  Please answer y or n${NC}” ;;
esac
done
}

step() {
echo “”
echo -e “${ORANGE}${BOLD}── $1 ──────────────────────────────────────────────${NC}”
}

ok() {
echo -e “${GREEN}  ✓ $1${NC}”
}

warn() {
echo -e “${YELLOW}  ⚠ $1${NC}”
}

fail() {
echo -e “${RED}  ✗ $1${NC}”
}

info() {
echo -e “${DIM}  $1${NC}”
}

# ── Gather configuration ──────────────────────────────────────

step “STEP 1 — User Information”
echo “”
CURRENT_USER=$(whoami)
CURRENT_HOME=$(eval echo ~$CURRENT_USER)
echo -e “  Detected username: ${WHITE}${CURRENT_USER}${NC}”
echo -e “  Detected home:     ${WHITE}${CURRENT_HOME}${NC}”
echo “”

ask_yn “Is this the correct username for this Mac?” “y” CORRECT_USER
if [ “$CORRECT_USER” = “no” ]; then
ask “Enter the correct username:” “$CURRENT_USER” CURRENT_USER
CURRENT_HOME=”/Users/$CURRENT_USER”
fi

step “STEP 2 — Network Configuration”
echo “”
echo -e “${DIM}  The bridge needs to know the IP addresses of both Macs.”
echo -e “  The standard ETC network range is 2.x.x.x${NC}”
echo “”

ask “IP address of THIS Mac (the one running the bridge):” “2.0.0.2” BRIDGE_IP
ask “IP address of the ETCnomad / Eos Mac:” “2.0.0.1” EOS_IP
ask “Eos OSC receive port (Eos listens on this):” “8000” EOS_PORT
ask “Bridge OSC listen port (bridge receives Eos feedback on this):” “9001” LISTEN_PORT
ask_yn “Is QLab running on this same Mac?” “y” QLAB_SAME_MAC

if [ “$QLAB_SAME_MAC” = “yes” ]; then
QLAB_IP=“127.0.0.1”
info “QLab IP set to 127.0.0.1 (localhost)”
else
ask “IP address of the QLab Mac:” “2.0.0.2” QLAB_IP
fi
ask “QLab OSC receive port:” “53000” QLAB_PORT

step “STEP 3 — Installation Path”
echo “”
ask “Where should the files be installed?” “$CURRENT_HOME/Documents” INSTALL_DIR

step “STEP 4 — Python Environment”
echo “”
ask “Where should the Python virtual environment be created?” “$CURRENT_HOME/scripts” VENV_PARENT
VENV_DIR=”$VENV_PARENT/venv”
info “Venv will be at: $VENV_DIR”

step “STEP 5 — APC Button Layout”
echo “”
echo -e “${DIM}  The installer will use the standard Eos layout.”
echo -e “  You can customise individual buttons after install using the web editor.${NC}”
echo “”
ask_yn “Use the standard Eos button layout?” “y” USE_STANDARD_LAYOUT

step “STEP 6 — Auto-start”
echo “”
ask_yn “Set up auto-start on login (recommended)?” “y” SETUP_AUTOSTART

step “STEP 7 — updateconfig Alias”
echo “”
ask_yn “Add updateconfig terminal alias?” “y” SETUP_ALIAS

# ── Summary ───────────────────────────────────────────────────

echo “”
echo -e “${ORANGE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}”
echo -e “${ORANGE}${BOLD}║                    CONFIGURATION SUMMARY                    ║${NC}”
echo -e “${ORANGE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}”
echo “”
echo -e “  ${WHITE}Username:${NC}         $CURRENT_USER”
echo -e “  ${WHITE}Home:${NC}             $CURRENT_HOME”
echo -e “  ${WHITE}Install dir:${NC}      $INSTALL_DIR”
echo -e “  ${WHITE}Venv:${NC}             $VENV_DIR”
echo -e “  ${WHITE}Bridge IP:${NC}        $BRIDGE_IP”
echo -e “  ${WHITE}Eos IP:${NC}           $EOS_IP”
echo -e “  ${WHITE}Eos OSC port:${NC}     $EOS_PORT”
echo -e “  ${WHITE}Bridge listen:${NC}    $LISTEN_PORT”
echo -e “  ${WHITE}QLab IP:${NC}          $QLAB_IP”
echo -e “  ${WHITE}QLab port:${NC}        $QLAB_PORT”
echo -e “  ${WHITE}Auto-start:${NC}       $SETUP_AUTOSTART”
echo -e “  ${WHITE}updateconfig:${NC}     $SETUP_ALIAS”
echo “”
ask_yn “Proceed with installation?” “y” PROCEED

if [ “$PROCEED” = “no” ]; then
echo “”
echo -e “${YELLOW}Installation cancelled.${NC}”
exit 0
fi

# ── Installation ──────────────────────────────────────────────

step “Installing — Creating directories”
mkdir -p “$INSTALL_DIR” && ok “Created $INSTALL_DIR”
mkdir -p “$VENV_PARENT” && ok “Created $VENV_PARENT”

step “Installing — Checking Python 3”
if command -v python3 &>/dev/null; then
PYVER=$(python3 –version 2>&1)
ok “Found $PYVER”
else
fail “Python 3 not found”
echo “”
echo -e “${YELLOW}  Install Python 3 from python.org or via Homebrew:${NC}”
echo -e “${DIM}  brew install python3${NC}”
echo “”
echo -e “${RED}  Installation cannot continue without Python 3.${NC}”
exit 1
fi

step “Installing — Creating virtual environment”
if [ -d “$VENV_DIR” ]; then
warn “Virtual environment already exists at $VENV_DIR — skipping creation”
else
python3 -m venv “$VENV_DIR”
ok “Created virtual environment at $VENV_DIR”
fi

step “Installing — Installing Python packages”
echo “”
info “Installing python-osc, mido, python-rtmidi…”
“$VENV_DIR/bin/pip” install –quiet python-osc mido python-rtmidi
if [ $? -eq 0 ]; then
ok “All packages installed”
else
fail “Package installation failed — check internet connection”
exit 1
fi

step “Installing — Writing eos_apc_config.json”
cat > “$INSTALL_DIR/eos_apc_config.json” << ENDJSON
{
“network”: {
“eos_ip”: “$EOS_IP”,
“eos_osc_port”: $EOS_PORT,
“qlab_ip”: “$QLAB_IP”,
“qlab_osc_port”: $QLAB_PORT,
“listen_port”: $LISTEN_PORT
},
“grid_buttons”: {
“56”: {“label”: “GO”,            “osc”: “/eos/key/go_0”,              “target”: “eos”,  “color”: 17, “use_val”: true,  “group”: “go”},
“57”: {“label”: “Stop”,          “osc”: “/eos/key/stop”,              “target”: “eos”,  “color”: 5,  “use_val”: true,  “group”: “destructive”},
“58”: {“label”: “Add/Patch”,     “osc”: “/eos/key/patch”,             “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“59”: {“label”: “ML Cntrl”,      “osc”: “/eos/key/open_ml_controls”,  “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“60”: {“label”: “S1”,            “osc”: “/eos/key/softkey_1”,         “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“61”: {“label”: “S2”,            “osc”: “/eos/key/softkey_2”,         “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“62”: {“label”: “S3”,            “osc”: “/eos/key/softkey_3”,         “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“63”: {“label”: “S4”,            “osc”: “/eos/key/softkey_4”,         “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“48”: {“label”: “Copy To”,       “osc”: “/eos/key/copy_to”,           “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“49”: {“label”: “Recall From”,   “osc”: “/eos/key/recall_from”,       “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“50”: {“label”: “Label”,         “osc”: “/eos/key/label”,             “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“51”: {“label”: “Mark”,          “osc”: “/eos/key/mark”,              “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“52”: {“label”: “Park”,          “osc”: “/eos/key/park”,              “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“53”: {“label”: “Sneak”,         “osc”: “/eos/key/sneak”,             “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“54”: {“label”: “Home”,          “osc”: “/eos/key/home”,              “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“55”: {“label”: “Shift”,         “osc”: null,                         “target”: null,   “color”: 3,  “use_val”: false, “group”: “shift”},
“40”: {“label”: “Intensity Pal”, “osc”: “/eos/key/intensity_palette”, “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“41”: {“label”: “Delete”,        “osc”: “/eos/key/delete”,            “target”: “eos”,  “color”: 6,  “use_val”: true,  “group”: “destructive”},
“42”: {“label”: “Cue”,           “osc”: “/eos/key/cue”,               “target”: “eos”,  “color”: 9,  “use_val”: true,  “group”: “command”},
“43”: {“label”: “Go To Cue”,     “osc”: “/eos/key/go_to_cue”,         “target”: “eos”,  “color”: 21, “use_val”: true,  “group”: “command”},
“44”: {“label”: “Block”,         “osc”: “/eos/key/block”,             “target”: “eos”,  “color”: 9,  “use_val”: true,  “group”: “command”},
“45”: {“label”: “Assert”,        “osc”: “/eos/key/assert”,            “target”: “eos”,  “color”: 9,  “use_val”: true,  “group”: “command”},
“46”: {“label”: “Undo”,          “osc”: “/eos/key/undo”,              “target”: “eos”,  “color”: 9,  “use_val”: true,  “group”: “command”},
“47”: {“label”: “Trace”,         “osc”: “/eos/key/trace”,             “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“32”: {“label”: “Focus Pal”,     “osc”: “/eos/key/focus_palette”,     “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“33”: {“label”: “Record”,        “osc”: “/eos/key/record”,            “target”: “eos”,  “color”: 6,  “use_val”: true,  “group”: “command”},
“34”: {“label”: “Sub”,           “osc”: “/eos/key/sub”,               “target”: “eos”,  “color”: 9,  “use_val”: true,  “group”: “command”},
“35”: {“label”: “+”,             “osc”: “/eos/key/+”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“36”: {“label”: “Thru”,          “osc”: “/eos/key/thru”,              “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“37”: {“label”: “-”,             “osc”: “/eos/key/-”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“38”: {“label”: “/”,             “osc”: “/eos/key/\\”,              “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“39”: {“label”: “Tab”,           “osc”: “/eos/key/tab”,               “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“24”: {“label”: “Colour Pal”,    “osc”: “/eos/key/color_palette”,     “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“25”: {“label”: “Update”,        “osc”: “/eos/key/update”,            “target”: “eos”,  “color”: 6,  “use_val”: true,  “group”: “command”},
“26”: {“label”: “Group”,         “osc”: “/eos/key/group”,             “target”: “eos”,  “color”: 9,  “use_val”: true,  “group”: “command”},
“27”: {“label”: “7”,             “osc”: “/eos/key/7”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“28”: {“label”: “8”,             “osc”: “/eos/key/8”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“29”: {“label”: “9”,             “osc”: “/eos/key/9”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“30”: {“label”: “Rem-Dim”,       “osc”: “/eos/key/rem_dim”,           “target”: “eos”,  “color”: 9,  “use_val”: true,  “group”: “command”},
“31”: {“label”: “Select Last”,   “osc”: “/eos/key/select_last”,       “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“16”: {“label”: “Beam Pal”,      “osc”: “/eos/key/beam_palette”,      “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“17”: {“label”: “Record Only”,   “osc”: “/eos/key/record_only”,       “target”: “eos”,  “color”: 6,  “use_val”: true,  “group”: “command”},
“18”: {“label”: “Part”,          “osc”: “/eos/key/part”,              “target”: “eos”,  “color”: 9,  “use_val”: true,  “group”: “command”},
“19”: {“label”: “4”,             “osc”: “/eos/key/4”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“20”: {“label”: “5”,             “osc”: “/eos/key/5”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“21”: {“label”: “6”,             “osc”: “/eos/key/6”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“22”: {“label”: “Out”,           “osc”: “/eos/key/out”,               “target”: “eos”,  “color”: 9,  “use_val”: true,  “group”: “command”},
“23”: {“label”: “Select Active”, “osc”: “/eos/key/select_active”,     “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“8”:  {“label”: “Preset”,        “osc”: “/eos/key/preset”,            “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“9”:  {“label”: “Time”,          “osc”: “/eos/key/time”,              “target”: “eos”,  “color”: 6,  “use_val”: true,  “group”: “command”},
“10”: {“label”: “+%”,            “osc”: “/eos/key/+%”,                “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“11”: {“label”: “1”,             “osc”: “/eos/key/1”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“12”: {“label”: “2”,             “osc”: “/eos/key/2”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“13”: {“label”: “3”,             “osc”: “/eos/key/3”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“14”: {“label”: “Full”,          “osc”: “/eos/key/full”,              “target”: “eos”,  “color”: 9,  “use_val”: true,  “group”: “command”},
“15”: {“label”: “Qonly/Track”,   “osc”: “/eos/key/cueonlytrack”,      “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“0”:  {“label”: “Effect”,        “osc”: “/eos/key/effect”,            “target”: “eos”,  “color”: 37, “use_val”: true,  “group”: “command”},
“1”:  {“label”: “Delay”,         “osc”: “/eos/key/delay”,             “target”: “eos”,  “color”: 6,  “use_val”: true,  “group”: “command”},
“2”:  {“label”: “-%”,            “osc”: “/eos/key/-%”,                “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“3”:  {“label”: “Clear”,         “osc”: “/eos/key/clear_cmd”,         “target”: “eos”,  “color”: 6,  “use_val”: true,  “group”: “destructive”},
“4”:  {“label”: “0”,             “osc”: “/eos/key/0”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“5”:  {“label”: “.”,             “osc”: “/eos/key/.”,                 “target”: “eos”,  “color”: 3,  “use_val”: true,  “group”: “numeric”},
“6”:  {“label”: “At”,            “osc”: “/eos/key/at”,                “target”: “eos”,  “color”: 9,  “use_val”: true,  “group”: “command”},
“7”:  {“label”: “Enter”,         “osc”: “/eos/key/enter”,             “target”: “eos”,  “color”: 21, “use_val”: true,  “group”: “command”}
},
“right_column”: {
“112”: {“label”: “Live”,    “osc”: “/eos/key/live”,               “use_val”: true},
“113”: {“label”: “Blind”,   “osc”: “/eos/key/blind”,              “use_val”: true},
“114”: {“label”: “Flexi”,   “osc”: “/eos/key/flexichannel_mode”,  “use_val”: true},
“115”: {“label”: “Channel”, “osc”: “/eos/key/chan”,               “use_val”: true},
“116”: {“label”: “Fixture”, “osc”: “/eos/key/fixture”,            “use_val”: false},
“117”: {“label”: “Next”,    “osc”: “/eos/key/next”,               “use_val”: true},
“118”: {“label”: “Prev”,    “osc”: “/eos/key/last”,               “use_val”: true},
“119”: {“label”: “Format”,  “osc”: “/eos/key/format”,             “use_val”: false}
},
“ml_params”: {
“0”: {“name”: “intens”,  “is_switch”: false, “min”: 0.0,  “max”: 100.0},
“1”: {“name”: “pan”,     “is_switch”: true,  “min”: null, “max”: null},
“2”: {“name”: “tilt”,    “is_switch”: true,  “min”: null, “max”: null},
“3”: {“name”: “zoom”,    “is_switch”: false, “min”: 0.0,  “max”: 100.0},
“4”: {“name”: “edge”,    “is_switch”: false, “min”: 0.0,  “max”: 100.0}
},
“color_params”: {
“0”: “red”,
“1”: “lime”,
“2”: “green”,
“3”: “blue”,
“4”: “hue”,
“5”: “saturation”,
“6”: null,
“7”: null
}
}
ENDJSON
ok “Written eos_apc_config.json”

step “Installing — Writing eos_apc_feedback.py”
PLIST_PATH=”$CURRENT_HOME/Library/LaunchAgents/com.eos.apcfeedback.plist”
python3 - << ENDPY
import os

script = ‘’’import time
import threading
import logging
import os
import json
import socket
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
from pythonosc import dispatcher, osc_server
from pythonosc import udp_client
import mido

CONFIG_FILE = os.path.expanduser(”~”) + “/Documents/eos_apc_config.json”
LOG_FILE    = os.path.expanduser(”~”) + “/Documents/eos_apc.log”

logging.basicConfig(level=logging.INFO, format=”%(asctime)s %(levelname)s %(message)s”,
handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler()])
log = logging.getLogger(“eos_apc”)

CH_BRIGHT = 5
CH_FULL = 6
CH_BLINK_FAST = 12
COLOR_OFF = 0
COLOR_WHITE = 3
COLOR_RED_STOP = 5
COLOR_GREEN_BRT = 17
COLOR_AMBER = 9
CONFIRM_FLASH = 0.05
MODE_SUB = “submaster”
MODE_ML = “ml_encoder”
MODE_COLOR = “color”
TRACK_BUTTONS = [0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B]
TRACK_MODE_ML_BUTTON = 0x6B
TRACK_MODE_COLOR_BUTTON = 0x6A
fader_cc_to_index = {0x30:0,0x31:1,0x32:2,0x33:3,0x34:4,0x35:5,0x36:6,0x37:7,0x38:8}
fader_index_to_track_note = {0:0x64,1:0x65,2:0x66,3:0x67,4:0x68,5:0x69,6:0x6A,7:0x6B}

STATUS_PORT = 9002
_status = {“eos_connected”: False, “qlab_reachable”: False, “fader_mode”: “submaster”, “apc_connected”: False}
_fire_callback = None
PLIST_PATH = os.path.expanduser(”~”) + “/Library/LaunchAgents/com.eos.apcfeedback.plist”

class StatusHandler(BaseHTTPRequestHandler):
def do_GET(self):
if self.path == “/status”:
data = json.dumps(_status).encode()
self.send_response(200)
self.send_header(“Content-Type”, “application/json”)
self.send_header(“Access-Control-Allow-Origin”, “*”)
self.send_header(“Content-Length”, len(data))
self.end_headers()
self.wfile.write(data)
else:
self.send_response(404)
self.end_headers()
def do_POST(self):
if self.path == “/fire”:
length = int(self.headers.get(“Content-Length”, 0))
body = self.rfile.read(length)
try:
req = json.loads(body)
osc = req.get(“osc”)
target = req.get(“target”, “eos”)
use_val = req.get(“use_val”, True)
if osc and _fire_callback:
_fire_callback(osc, target, use_val)
self.send_response(200)
self.send_header(“Content-Type”, “application/json”)
self.send_header(“Access-Control-Allow-Origin”, “*”)
self.end_headers()
self.wfile.write(b”{” + b’“ok”:true’ + b”}”)
except Exception as e:
self.send_response(500)
self.end_headers()
elif self.path == “/reload”:
script = “sleep 2 && launchctl unload “ + PLIST_PATH + “ && sleep 2 && launchctl load “ + PLIST_PATH
subprocess.Popen([“bash”, “-c”, script], close_fds=True, start_new_session=True)
self.send_response(200)
self.send_header(“Content-Type”, “application/json”)
self.send_header(“Access-Control-Allow-Origin”, “*”)
self.end_headers()
self.wfile.write(b”{” + b’“ok”:true’ + b”}”)
else:
self.send_response(404)
self.end_headers()
def do_OPTIONS(self):
self.send_response(200)
self.send_header(“Access-Control-Allow-Origin”, “*”)
self.send_header(“Access-Control-Allow-Methods”, “GET, POST, OPTIONS”)
self.send_header(“Access-Control-Allow-Headers”, “Content-Type”)
self.end_headers()
def log_message(self, format, *args):
pass

def start_status_server():
try:
srv = HTTPServer((“127.0.0.1”, STATUS_PORT), StatusHandler)
log.info(”[STATUS] HTTP server on port “ + str(STATUS_PORT))
srv.serve_forever()
except Exception as e:
log.warning(”[STATUS] Could not start: “ + str(e))

def check_qlab(ip, port):
try:
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(1)
result = s.connect_ex((ip, port))
s.close()
return result == 0
except:
return False

def find_apc_out():
for name in mido.get_output_names():
if “APC mini mk2”.lower() in name.lower():
return name
return None

def find_apc_in():
for name in mido.get_input_names():
if “APC mini mk2”.lower() in name.lower():
return name
return None

def load_config():
if not os.path.exists(CONFIG_FILE):
log.error(”[CFG] Not found: “ + CONFIG_FILE)
raise SystemExit(1)
with open(CONFIG_FILE) as f:
cfg = json.load(f)
log.info(”[CFG] Loaded: “ + CONFIG_FILE)
net = cfg.get(“network”, {})
EOS_IP = net.get(“eos_ip”, “2.0.0.1”)
EOS_OSC_PORT = net.get(“eos_osc_port”, 8000)
QLAB_IP = net.get(“qlab_ip”, “2.0.0.2”)
QLAB_OSC_PORT = net.get(“qlab_osc_port”, 53000)
LISTEN_PORT = net.get(“listen_port”, 9001)
BUTTON_MAP = {}
for note_str, d in cfg.get(“grid_buttons”, {}).items():
BUTTON_MAP[int(note_str)] = (
d.get(“label”,””), d.get(“color”,0), d.get(“group”,“command”),
d.get(“osc”,None), d.get(“target”,“eos”), d.get(“use_val”,True))
RC_MAP = {}
for note_str, d in cfg.get(“right_column”, {}).items():
RC_MAP[int(note_str)] = (d.get(“label”,””), d.get(“osc”,None), d.get(“use_val”,True))
ML_PARAMS = {}
for idx_str, d in cfg.get(“ml_params”, {}).items():
ML_PARAMS[int(idx_str)] = (d.get(“name”,“intens”), d.get(“is_switch”,False), d.get(“min”,0.0), d.get(“max”,100.0))
COLOR_PARAMS = {}
for idx_str, val in cfg.get(“color_params”, {}).items():
COLOR_PARAMS[int(idx_str)] = val
RIGHT_COLUMN_NOTES = sorted(RC_MAP.keys())
return (EOS_IP, EOS_OSC_PORT, QLAB_IP, QLAB_OSC_PORT, LISTEN_PORT,
BUTTON_MAP, RC_MAP, ML_PARAMS, COLOR_PARAMS, RIGHT_COLUMN_NOTES)

def send_led(port, note, color, channel=CH_FULL):
port.send(mido.Message(“note_on”, channel=channel, note=note, velocity=color))

def send_peripheral_led(port, note, state):
port.send(mido.Message(“note_on”, channel=0, note=note, velocity=state))

def grid_note(row, col):
return (7 - row) * 8 + col

def self_test(port):
log.info(”[TEST] Starting”)
for note in range(0, 64):
for color in [5, 9, 17, 37, 3]:
send_led(port, note, color, channel=CH_FULL)
time.sleep(0.008)
send_led(port, note, COLOR_OFF)
for note in [0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77]:
send_peripheral_led(port, note, 2)
time.sleep(0.04)
send_peripheral_led(port, note, 0)
for note in TRACK_BUTTONS:
send_peripheral_led(port, note, 2)
time.sleep(0.04)
send_peripheral_led(port, note, 0)
log.info(”[TEST] Done”)

def hello_animation(port):
H=[(0,0),(1,0),(2,0),(2,1),(2,2),(3,0),(4,0),(0,2),(1,2),(3,2),(4,2)]
E=[(0,0),(0,1),(0,2),(1,0),(2,0),(2,1),(3,0),(4,0),(4,1),(4,2)]
L=[(0,0),(1,0),(2,0),(3,0),(4,0),(4,1),(4,2)]
O=[(0,0),(0,1),(0,2),(1,0),(1,2),(2,0),(2,2),(3,0),(3,2),(4,0),(4,1),(4,2)]
letters = [H, E, L, L, O]
colors = [5, 13, 21, 21, 37]
full = {}
col_off = 0
for letter, color in zip(letters, colors):
for (r, c) in letter:
full[(r, col_off + c)] = color
col_off += 4
for scroll in range(col_off + 8):
for note in range(64):
send_led(port, note, COLOR_OFF)
for (r, c), color in full.items():
sc = c - scroll + 8
if 0 <= sc <= 7 and 0 <= r <= 7:
send_led(port, grid_note(r, sc), color, channel=CH_FULL)
time.sleep(0.07)
for note in range(64):
send_led(port, note, COLOR_OFF)
log.info(”[ANIM] HELLO done”)

def set_all_idle(port, BUTTON_MAP, RIGHT_COLUMN_NOTES, fader_mode, eos_connected):
for note, data in BUTTON_MAP.items():
send_led(port, note, data[1], channel=CH_BRIGHT)
time.sleep(0.004)
for note in RIGHT_COLUMN_NOTES:
send_peripheral_led(port, note, 1)
for note in TRACK_BUTTONS:
send_peripheral_led(port, note, 0)
update_mode_leds(port, fader_mode)
if eos_connected:
send_led(port, 56, COLOR_GREEN_BRT, channel=CH_BRIGHT)
else:
send_led(port, 56, COLOR_RED_STOP, channel=CH_BLINK_FAST)

def set_go_running(port):
send_led(port, 56, COLOR_GREEN_BRT, channel=CH_BLINK_FAST)

def set_go_idle(port, eos_connected):
if eos_connected:
send_led(port, 56, COLOR_GREEN_BRT, channel=CH_BRIGHT)
else:
send_led(port, 56, COLOR_RED_STOP, channel=CH_BLINK_FAST)

def update_mode_leds(port, fader_mode):
send_peripheral_led(port, TRACK_MODE_ML_BUTTON, 2 if fader_mode == MODE_ML else 0)
send_peripheral_led(port, TRACK_MODE_COLOR_BUTTON, 2 if fader_mode == MODE_COLOR else 0)

def send_osc(eos_client, qlab_client, osc_cmd, target, use_val, press=True):
if not osc_cmd:
return
try:
if target == “qlab”:
qlab_client.send_message(osc_cmd, 1 if press else 0)
else:
if use_val:
eos_client.send_message(osc_cmd, 1 if press else 0)
elif press:
eos_client.send_message(osc_cmd, [])
log.info(”[OSC->” + target + “] “ + osc_cmd)
except Exception as e:
log.error(”[ERROR] “ + str(e))

def main():
(EOS_IP, EOS_OSC_PORT, QLAB_IP, QLAB_OSC_PORT, LISTEN_PORT,
BUTTON_MAP, RC_MAP, ML_PARAMS, COLOR_PARAMS, RIGHT_COLUMN_NOTES) = load_config()
log.info(“Bridge v16.0 starting”)
eos_client = udp_client.SimpleUDPClient(EOS_IP, EOS_OSC_PORT)
qlab_client = udp_client.SimpleUDPClient(QLAB_IP, QLAB_OSC_PORT)
global _fire_callback
def _do_fire(osc, target, use_val):
try:
if target == “qlab”:
qlab_client.send_message(osc, 1)
else:
if use_val:
eos_client.send_message(osc, 1)
else:
eos_client.send_message(osc, [])
log.info(”[WEB FIRE] “ + osc)
except Exception as e:
log.error(”[WEB FIRE ERROR] “ + str(e))
_fire_callback = _do_fire
fader_mode = MODE_SUB
cue_active = False
blind_active = False
eos_connected = False
last_pong_time = time.time()
held_notes = {}
last_fader_val = {}
switch_active = {}
switch_events = {}
midi_out_ref = [None]
apc_lock = threading.Lock()

```
def stop_switch(idx):
    if idx in switch_events:
        switch_events[idx].set()
        del switch_events[idx]
    if idx in switch_active:
        param = switch_active.pop(idx)
        try:
            eos_client.send_message("/eos/switch/" + param, 0.0)
        except:
            pass

def start_switch(idx, param, tick):
    stop_switch(idx)
    ev = threading.Event()
    switch_events[idx] = ev
    switch_active[idx] = param
    def _loop():
        while not ev.is_set():
            try:
                eos_client.send_message("/eos/switch/" + param, tick)
            except:
                pass
            time.sleep(0.05)
        try:
            eos_client.send_message("/eos/switch/" + param, 0.0)
        except:
            pass
    threading.Thread(target=_loop, daemon=True).start()

def on_btn_press(note):
    nonlocal fader_mode
    if note not in BUTTON_MAP:
        return
    label, color, group, osc, target, use_val = BUTTON_MAP[note]
    if group == "shift":
        with apc_lock:
            if midi_out_ref[0]:
                send_led(midi_out_ref[0], note, COLOR_WHITE, channel=CH_FULL)
        return
    held_notes[note] = BUTTON_MAP[note]
    with apc_lock:
        if midi_out_ref[0]:
            send_led(midi_out_ref[0], note, COLOR_AMBER if group == "numeric" else COLOR_WHITE, channel=CH_FULL)
    send_osc(eos_client, qlab_client, osc, target, use_val, press=True)

def on_btn_release(note):
    if note not in BUTTON_MAP:
        return
    label, color, group, osc, target, use_val = BUTTON_MAP[note]
    if group == "shift":
        with apc_lock:
            if midi_out_ref[0]:
                send_led(midi_out_ref[0], note, color, channel=CH_BRIGHT)
        return
    held_notes.pop(note, None)
    if use_val:
        send_osc(eos_client, qlab_client, osc, target, use_val, press=False)
    def _flash():
        with apc_lock:
            if midi_out_ref[0]:
                send_led(midi_out_ref[0], note, COLOR_WHITE, channel=CH_FULL)
        time.sleep(CONFIRM_FLASH)
        with apc_lock:
            if midi_out_ref[0]:
                send_led(midi_out_ref[0], note, color, channel=CH_BRIGHT)
    threading.Thread(target=_flash, daemon=True).start()

def on_rc_press(note):
    if note not in RC_MAP:
        return
    label, osc, use_val = RC_MAP[note]
    with apc_lock:
        if midi_out_ref[0]:
            send_peripheral_led(midi_out_ref[0], note, 2)
    send_osc(eos_client, qlab_client, osc, "eos", use_val, press=True)

def on_rc_release(note):
    if note not in RC_MAP:
        return
    label, osc, use_val = RC_MAP[note]
    if use_val:
        send_osc(eos_client, qlab_client, osc, "eos", use_val, press=False)
    if not (note == 0x71 and blind_active):
        with apc_lock:
            if midi_out_ref[0]:
                send_peripheral_led(midi_out_ref[0], note, 1)

def on_track_press(note):
    nonlocal fader_mode
    if note == TRACK_MODE_ML_BUTTON:
        fader_mode = MODE_SUB if fader_mode == MODE_ML else MODE_ML
        _status["fader_mode"] = fader_mode
        with apc_lock:
            if midi_out_ref[0]:
                update_mode_leds(midi_out_ref[0], fader_mode)
        log.info("[MODE] " + fader_mode)
        return
    if note == TRACK_MODE_COLOR_BUTTON:
        fader_mode = MODE_SUB if fader_mode == MODE_COLOR else MODE_COLOR
        _status["fader_mode"] = fader_mode
        with apc_lock:
            if midi_out_ref[0]:
                update_mode_leds(midi_out_ref[0], fader_mode)
        log.info("[MODE] " + fader_mode)
        return
    idx = next((i for i,n in fader_index_to_track_note.items() if n==note), None)
    if idx is not None and fader_mode == MODE_ML and idx in switch_active:
        stop_switch(idx)
        with apc_lock:
            if midi_out_ref[0]:
                send_peripheral_led(midi_out_ref[0], note, 0)
    else:
        with apc_lock:
            if midi_out_ref[0]:
                send_peripheral_led(midi_out_ref[0], note, 2)

def on_track_release(note):
    if note in (TRACK_MODE_ML_BUTTON, TRACK_MODE_COLOR_BUTTON):
        return
    idx = next((i for i,n in fader_index_to_track_note.items() if n==note), None)
    if idx is not None and fader_mode == MODE_ML and idx in switch_active:
        return
    def _f():
        time.sleep(CONFIRM_FLASH)
        with apc_lock:
            if midi_out_ref[0]:
                send_peripheral_led(midi_out_ref[0], note, 0)
    threading.Thread(target=_f, daemon=True).start()

def on_fader(cc, value):
    nonlocal fader_mode
    idx = fader_cc_to_index.get(cc)
    if idx is None:
        return
    normalized = value / 127.0
    prev = last_fader_val.get(cc, value)
    delta = value - prev
    last_fader_val[cc] = value
    if fader_mode == MODE_SUB:
        if idx < 8:
            eos_client.send_message("/eos/sub/" + str(idx+1), normalized)
        else:
            eos_client.send_message("/eos/grandmaster", normalized)
    elif fader_mode == MODE_ML:
        if idx < 5:
            param_name, is_switch, p_min, p_max = ML_PARAMS.get(idx, ("intens",False,0,100))
            if is_switch:
                if delta != 0:
                    tick = float(delta) / 5.0
                    start_switch(idx, param_name, tick)
                    t_note = fader_index_to_track_note.get(idx)
                    if t_note and t_note not in (TRACK_MODE_ML_BUTTON, TRACK_MODE_COLOR_BUTTON):
                        with apc_lock:
                            if midi_out_ref[0]:
                                send_peripheral_led(midi_out_ref[0], t_note, 2)
            else:
                scaled = p_min + (normalized * (p_max - p_min))
                eos_client.send_message("/eos/param/" + param_name, scaled)
    elif fader_mode == MODE_COLOR:
        if idx < 8:
            param = COLOR_PARAMS.get(idx)
            if param:
                eos_client.send_message("/eos/param/" + param, normalized * 100.0)
        else:
            eos_client.send_message("/eos/grandmaster", normalized)

def handle_active_cue(addr, *args):
    nonlocal cue_active, eos_connected, last_pong_time
    last_pong_time = time.time()
    eos_connected = True
    _status["eos_connected"] = True
    value = args[0] if args else 0
    with apc_lock:
        port = midi_out_ref[0]
    if not port:
        return
    if value and float(value) == 1.0:
        cue_active = False
        set_go_idle(port, eos_connected)
    elif value and 0.0 < float(value) < 1.0:
        if not cue_active:
            cue_active = True
            set_go_running(port)
    else:
        cue_active = False
        set_go_idle(port, eos_connected)

def handle_blind(addr, *args):
    nonlocal blind_active
    value = args[0] if args else 0
    blind_active = bool(value)
    with apc_lock:
        if midi_out_ref[0]:
            send_peripheral_led(midi_out_ref[0], 0x71, 2 if blind_active else 1)

def handle_live(addr, *args):
    nonlocal eos_connected, last_pong_time
    last_pong_time = time.time()
    eos_connected = True
    _status["eos_connected"] = True
    with apc_lock:
        if midi_out_ref[0]:
            send_peripheral_led(midi_out_ref[0], 0x70, 2 if (args and args[0]) else 1)

def handle_ping(addr, *args):
    nonlocal eos_connected, last_pong_time
    last_pong_time = time.time()
    if not eos_connected:
        eos_connected = True
        _status["eos_connected"] = True
        log.info("[NET] Eos connected")
        with apc_lock:
            if midi_out_ref[0]:
                set_go_idle(midi_out_ref[0], eos_connected)

def handle_fallback(addr, *args):
    nonlocal eos_connected, last_pong_time
    last_pong_time = time.time()
    eos_connected = True
    _status["eos_connected"] = True

def ping_loop():
    nonlocal eos_connected, last_pong_time
    last_ping = time.time()
    while True:
        now = time.time()
        if now - last_ping >= 3:
            try:
                eos_client.send_message("/eos/ping", [])
            except:
                pass
            last_ping = now
        if eos_connected and (now - last_pong_time > 8):
            eos_connected = False
            _status["eos_connected"] = False
            log.warning("[NET] Eos disconnected")
            with apc_lock:
                if midi_out_ref[0]:
                    send_led(midi_out_ref[0], 56, COLOR_RED_STOP, channel=CH_BLINK_FAST)
        time.sleep(0.5)

def midi_in_loop(port_name):
    log.info("[MIDI] Input loop started: " + port_name)
    try:
        with mido.open_input(port_name) as mi:
            for msg in mi:
                if msg.type == "control_change":
                    on_fader(msg.control, msg.value)
                elif msg.type == "note_on" and msg.velocity > 0:
                    log.info("[MIDI IN] note=" + str(msg.note) + " hex=" + hex(msg.note))
                    if msg.note in BUTTON_MAP:
                        on_btn_press(msg.note)
                    elif msg.note in RC_MAP:
                        on_rc_press(msg.note)
                    elif msg.note in TRACK_BUTTONS:
                        on_track_press(msg.note)
                elif (msg.type == "note_on" and msg.velocity == 0) or msg.type == "note_off":
                    if msg.note in BUTTON_MAP:
                        on_btn_release(msg.note)
                    elif msg.note in RC_MAP:
                        on_rc_release(msg.note)
                    elif msg.note in TRACK_BUTTONS:
                        on_track_release(msg.note)
    except Exception as e:
        log.warning("[MIDI] Input loop ended: " + str(e))

def apc_watchdog():
    nonlocal fader_mode, eos_connected
    log.info("[WATCHDOG] Starting APC reconnect monitor")
    while True:
        apc_out = find_apc_out()
        apc_in = find_apc_in()
        if apc_out and apc_in:
            log.info("[WATCHDOG] APC found: " + apc_out)
            _status["apc_connected"] = True
            try:
                with mido.open_output(apc_out) as midi_out:
                    with apc_lock:
                        midi_out_ref[0] = midi_out
                    time.sleep(0.5)
                    self_test(midi_out)
                    time.sleep(0.2)
                    hello_animation(midi_out)
                    time.sleep(0.2)
                    set_all_idle(midi_out, BUTTON_MAP, RIGHT_COLUMN_NOTES, fader_mode, eos_connected)
                    in_thread = threading.Thread(target=midi_in_loop, args=(apc_in,), daemon=True)
                    in_thread.start()
                    in_thread.join()
                    with apc_lock:
                        midi_out_ref[0] = None
                    log.warning("[WATCHDOG] APC disconnected - retrying in 2s")
                    _status["apc_connected"] = False
            except Exception as e:
                log.warning("[WATCHDOG] APC error: " + str(e))
                with apc_lock:
                    midi_out_ref[0] = None
                _status["apc_connected"] = False
        else:
            log.info("[WATCHDOG] APC not found - retrying in 2s")
            _status["apc_connected"] = False
        time.sleep(2)

def qlab_check_loop():
    while True:
        _status["qlab_reachable"] = check_qlab(QLAB_IP, QLAB_OSC_PORT)
        time.sleep(5)

threading.Thread(target=start_status_server, daemon=True).start()
threading.Thread(target=ping_loop, daemon=True).start()
threading.Thread(target=qlab_check_loop, daemon=True).start()
threading.Thread(target=apc_watchdog, daemon=True).start()

disp = dispatcher.Dispatcher()
disp.map("/eos/out/active/cue", handle_active_cue)
disp.map("/eos/out/blind", handle_blind)
disp.map("/eos/out/live", handle_live)
disp.map("/eos/out/ping", handle_ping)
disp.set_default_handler(handle_fallback)
server = osc_server.ThreadingOSCUDPServer(("0.0.0.0", LISTEN_PORT), disp)
log.info("[OSC] Listening on port " + str(LISTEN_PORT))
log.info("Ready. v16.0")
try:
    server.serve_forever()
except KeyboardInterrupt:
    log.info("Shutting down...")
    with apc_lock:
        if midi_out_ref[0]:
            for note in range(64):
                send_led(midi_out_ref[0], note, COLOR_OFF)
            for note in RIGHT_COLUMN_NOTES:
                send_peripheral_led(midi_out_ref[0], note, 0)
            for note in TRACK_BUTTONS:
                send_peripheral_led(midi_out_ref[0], note, 0)
    time.sleep(0.1)
```

if **name** == “**main**”:
main()
‘’’

install_dir = “$INSTALL_DIR”
out_path = install_dir + “/eos_apc_feedback.py”
with open(out_path, “w”) as f:
f.write(script)
print(“Written “ + out_path)
ENDPY
ok “Written eos_apc_feedback.py”

step “Installing — Verifying Python syntax”
“$VENV_DIR/bin/python3” -c “import ast; ast.parse(open(’$INSTALL_DIR/eos_apc_feedback.py’).read()); print(‘Syntax OK’)”
if [ $? -eq 0 ]; then
ok “Syntax verified clean”
else
fail “Syntax error in script — please report this”
exit 1
fi

step “Installing — Writing eos_apc_editor.html”

# Copy the HTML file if it exists next to the installer, otherwise note it

SCRIPT_DIR=”$(cd “$(dirname “$0”)” && pwd)”
if [ -f “$SCRIPT_DIR/eos_apc_editor.html” ]; then
cp “$SCRIPT_DIR/eos_apc_editor.html” “$INSTALL_DIR/eos_apc_editor.html”
ok “Copied eos_apc_editor.html from installer directory”
else
warn “eos_apc_editor.html not found next to installer”
warn “Copy it manually to $INSTALL_DIR/eos_apc_editor.html”
fi

if [ “$SETUP_AUTOSTART” = “yes” ]; then
step “Installing — Creating launch agent”
mkdir -p “$CURRENT_HOME/Library/LaunchAgents”
cat > “$CURRENT_HOME/Library/LaunchAgents/com.eos.apcfeedback.plist” << ENDPLIST

<?xml version="1.0" encoding="UTF-8"?>

<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">

<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.eos.apcfeedback</string>
    <key>ProgramArguments</key>
    <array>
        <string>$VENV_DIR/bin/python3</string>
        <string>$INSTALL_DIR/eos_apc_feedback.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/eos_apc.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/eos_apc.log</string>
</dict>
</plist>
ENDPLIST
    ok "Written launch agent plist"

```
launchctl load "$CURRENT_HOME/Library/LaunchAgents/com.eos.apcfeedback.plist" 2>/dev/null
if [ $? -eq 0 ]; then
    ok "Launch agent loaded and started"
else
    warn "Could not load launch agent automatically — run manually:"
    info "launchctl load ~/Library/LaunchAgents/com.eos.apcfeedback.plist"
fi
```

fi

if [ “$SETUP_ALIAS” = “yes” ]; then
step “Installing — Adding updateconfig alias”
ALIAS_CMD=“alias updateconfig="cp ~/Downloads/eos_apc_config.json $INSTALL_DIR/eos_apc_config.json && echo Config updated"”
SHELL_RC=”$CURRENT_HOME/.zshrc”
if [ -f “$CURRENT_HOME/.bash_profile” ] && [ ! -f “$CURRENT_HOME/.zshrc” ]; then
SHELL_RC=”$CURRENT_HOME/.bash_profile”
fi
if grep -q “updateconfig” “$SHELL_RC” 2>/dev/null; then
warn “updateconfig alias already exists in $SHELL_RC — skipping”
else
echo “$ALIAS_CMD” >> “$SHELL_RC”
ok “Added updateconfig alias to $SHELL_RC”
info “Run ‘source $SHELL_RC’ or open a new terminal to activate”
fi
fi

# ── Final summary ─────────────────────────────────────────────

echo “”
echo -e “${ORANGE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}”
echo -e “${ORANGE}${BOLD}║                    INSTALLATION COMPLETE                    ║${NC}”
echo -e “${ORANGE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}”
echo “”
echo -e “${GREEN}  Files installed:${NC}”
echo -e “  ${WHITE}$INSTALL_DIR/eos_apc_feedback.py${NC}”
echo -e “  ${WHITE}$INSTALL_DIR/eos_apc_config.json${NC}”
echo -e “  ${WHITE}$INSTALL_DIR/eos_apc_editor.html${NC}”
echo -e “  ${WHITE}$INSTALL_DIR/eos_apc.log${NC}  (created on first run)”
echo “”
echo -e “${GREEN}  Python environment:${NC}  $VENV_DIR”
if [ “$SETUP_AUTOSTART” = “yes” ]; then
echo -e “${GREEN}  Launch agent:${NC}        ~/Library/LaunchAgents/com.eos.apcfeedback.plist”
fi
echo “”
echo -e “${YELLOW}${BOLD}  Next steps:${NC}”
echo -e “  1. In ETCnomad: Setup > System > Show Control > OSC”
echo -e “     Set TX IP to ${WHITE}$BRIDGE_IP${NC} and TX Port to ${WHITE}$LISTEN_PORT${NC}”
echo -e “     Set RX Port to ${WHITE}$EOS_PORT${NC}”
echo “”
echo -e “  2. Connect the APC mini mk2 via USB”
echo “”
echo -e “  3. Watch the APC light up with the self-test and HELLO animation”
echo “”
echo -e “  4. Open ${WHITE}$INSTALL_DIR/eos_apc_editor.html${NC} in Chrome”
echo -e “     to configure buttons and monitor connection status”
echo “”
echo -e “  5. Check the log at any time:”
echo -e “     ${DIM}tail -f $INSTALL_DIR/eos_apc.log${NC}”
echo “”
if [ “$SETUP_ALIAS” = “yes” ]; then
echo -e “  6. After saving config changes in the editor, deploy with:”
echo -e “     ${DIM}updateconfig${NC}  (after opening a new terminal)”
echo “”
fi
echo -e “${DIM}  For troubleshooting, see the manual: eos_apc_manual.docx${NC}”
echo “”