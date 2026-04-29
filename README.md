# APC mk2 / EOS Bridge

A Python-based bridge that transforms an **Akai APC mini mk2** MIDI controller into a full-featured **ETC Eos family** lighting control surface — with real-time RGB LED feedback, fader control, OSC communication, auto-reconnect, and a touchscreen web editor.

Built for touring and theatrical use. Runs silently at boot on a Mac mini, requires no additional hardware beyond what is already in the rig.

-----

## ⚠️ Disclaimer

**This project was developed with the assistance of AI (Claude by Anthropic).**

It is provided as-is, without warranty of any kind. Use at your own risk. Always have a backup control method available in a live show environment. Test thoroughly before using in production.

Feedback, bug reports and improvements are warmly welcomed — open an issue or submit a pull request.

-----

## What It Does

- Maps all 64 APC mk2 grid buttons to Eos OSC key commands
- Real-time RGB LED feedback — buttons light up in colour-coded groups
- GO button blinks green while a cue runs, blinks red if Eos goes offline
- Blind mode, Live mode and cue state reflected on the hardware
- 9 faders operate in three switchable modes:
  - **Submaster mode** — faders 1–8 control Eos submasters, fader 9 = grandmaster
  - **ML encoder mode** — faders control Intensity, Pan, Tilt, Zoom, Edge on selected fixtures
  - **Colour mode** — faders control Red, Lime, Green, Blue, Hue, Saturation
- Auto-reconnect — if the APC USB disconnects, the bridge detects it and reconnects automatically
- Auto-start at boot via macOS Launch Agent
- Startup self-test LED sweep and HELLO animation
- Web-based configuration editor — edit every button, colour and OSC command without touching code
- iPad Progressive Web App — install the editor to the iPad home screen
- Live status monitoring — Eos, QLab, Bridge and APC connection state visible in the editor
- One-tap bridge reload from the editor
- Full logging to `~/Documents/eos_apc.log`

-----

## Hardware Requirements

- Mac running macOS (tested on M4 Mac mini)
- Akai APC mini mk2 connected via USB
- ETC Eos family console or ETCnomad on a second machine
- Both machines connected via Ethernet on the same network
- Recommended network: `2.x.x.x / 255.0.0.0` static IPs (ETC standard)

-----

## File Overview

|File                         |Description                                  |
|-----------------------------|---------------------------------------------|
|`eos_apc_feedback.py`        |Main Python bridge script                    |
|`eos_apc_config.json`        |Button layout, OSC commands, network settings|
|`eos_apc_editor.html`        |Desktop web configuration editor             |
|`APC-EOS_bridge_installer.sh`|Interactive installer for new Mac setups     |
|`apc-pwa/`                   |iPad Progressive Web App files               |
|`install_ipad_pwa.sh`        |iPad PWA installer                           |

-----

## Quick Install

### Automated (recommended)

```bash
git clone https://github.com/sandalphonqlab/APC_MK2-EOS-Bridge.git
cd APC_MK2-EOS-Bridge
chmod +x APC-EOS_bridge_installer.sh
./APC-EOS_bridge_installer.sh
```

The installer will ask for your network settings, install all Python dependencies, write the config, create the launch agent and set up auto-start.

### Requirements

Install Python 3 if not already present:

```bash
brew install python3
```

Or download from [python.org](https://python.org).

-----

## ETCnomad / Eos OSC Setup

In ETCnomad: **Setup → System → Show Control → OSC**

|Setting       |Value                                          |
|--------------|-----------------------------------------------|
|OSC RX Enabled|Yes                                            |
|OSC RX Port   |8000                                           |
|OSC TX Enabled|Yes                                            |
|OSC TX IP     |IP of the Mac running the bridge (e.g. 2.0.0.2)|
|OSC TX Port   |9001                                           |

-----

## Network Configuration

Default IP scheme (edit in `eos_apc_config.json` or via the web editor):

|Device           |IP     |
|-----------------|-------|
|ETCnomad Mac     |2.0.0.1|
|Bridge Mac (QLab)|2.0.0.2|

-----

## Web Editor

Open `eos_apc_editor.html` in Chrome on the Mac. The editor shows:

- Live connection status for Eos, QLab, Bridge and APC
- Full 8×8 button grid with colour preview
- Click any button to edit its label, OSC command, LED colour and trigger type
- Network settings
- ML fader parameter assignments
- Colour mode fader assignments
- One-tap RELOAD button to restart the bridge

### Saving changes

1. Make changes in the editor
1. Click **Save JSON** — downloads `eos_apc_config.json` to `~/Downloads/`
1. In Terminal: `updateconfig`
1. Click **RELOAD** in the editor

-----

## iPad App

The editor can be installed as a Progressive Web App on iPad or iPhone.

```bash
chmod +x install_ipad_pwa.sh
./install_ipad_pwa.sh
```

Then open the printed URL in Safari on the iPad and tap **Share → Add to Home Screen**.

The app runs full screen with three tabs — Grid, Settings and Status. Tap a button to fire its OSC command instantly. Hold a button to edit it.

-----

## Important — Python Script Corruption

macOS automatically substitutes straight quotes with curly/smart quotes in downloaded `.py` files. Python cannot parse smart quotes and will throw a `SyntaxError`.

**Never** download `eos_apc_feedback.py` from a browser and open it in a text editor. Always use Git to clone or pull the script:

```bash
git clone https://github.com/sandalphonqlab/APC_MK2-EOS-Bridge.git
```

If the script does get corrupted, clean it with:

```bash
python3 << 'PYEOF'
content = open('/Users/YOUR_USERNAME/Documents/eos_apc_feedback.py', 'rb').read()
content = content.replace(b'\xe2\x80\x9c', b'"').replace(b'\xe2\x80\x9d', b'"')
content = content.replace(b'\xe2\x80\x98', b"'").replace(b'\xe2\x80\x99', b"'")
open('/Users/YOUR_USERNAME/Documents/eos_apc_feedback.py', 'wb').write(content)
print('Fixed')
PYEOF
```

-----

## Troubleshooting

**APC is dark and not responding**

```bash
launchctl unload ~/Library/LaunchAgents/com.eos.apcfeedback.plist
pkill -f eos_apc_feedback.py
launchctl load ~/Library/LaunchAgents/com.eos.apcfeedback.plist
```

**GO button blinking red**
Eos is not responding. Check ETCnomad is running and OSC TX is pointing to the correct IP and port.

**Script fails with SyntaxError**
Smart quote corruption. See the Python Script Corruption section above.

**Check the log**

```bash
tail -f ~/Documents/eos_apc.log
```

**Check the bridge is running**

```bash
launchctl list | grep apcfeedback
```

A number in the first column means running. A dash means crashed.

-----

## Key OSC Notes

- `/eos/key/clear_cmd` — use this for Clear, **not** `/eos/key/clear` which clears show data
- `/eos/key/flexichannel_mode` — Flexi key (no underscore between flexi and channel)
- `/eos/key/format` — send with empty `[]` value, not `1/0`
- `/eos/key/fixture` — send with empty `[]` value

-----

## Python Dependencies

```bash
pip install python-osc mido python-rtmidi
```

Or use the installer which handles this automatically in a virtual environment.

-----

## Version

**v16.0** — Auto-reconnect, config-driven, web editor, iPad PWA, status API, OSC fire API

-----

## Licence

MIT License — see <LICENSE> file.

Free to use, modify and distribute. Attribution appreciated but not required.

-----

## Feedback & Contributions

This project was built for a specific touring rig and may need adaptation for other setups. If you use it, adapt it, fix it or improve it — please share back.

Open an issue for bugs or questions. Pull requests welcome.

-----

*Developed with AI assistance (Claude by Anthropic). Use at your own risk in live show environments. Always test before going to show.*