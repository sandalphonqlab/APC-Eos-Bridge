import time
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

CONFIG_FILE = os.path.expanduser("~/Documents/eos_apc_config.json")
LOG_FILE = os.path.expanduser("~/Documents/eos_apc.log")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler()])
log = logging.getLogger("eos_apc")

CH_BRIGHT = 5
CH_FULL = 6
CH_BLINK_FAST = 12
COLOR_OFF = 0
COLOR_WHITE = 3
COLOR_RED_STOP = 5
COLOR_GREEN_BRT = 17
COLOR_AMBER = 9
CONFIRM_FLASH = 0.05
MODE_SUB = "submaster"
MODE_ML = "ml_encoder"
MODE_COLOR = "color"
TRACK_BUTTONS = [0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B]
TRACK_MODE_ML_BUTTON = 0x6B
TRACK_MODE_COLOR_BUTTON = 0x6A
fader_cc_to_index = {0x30:0,0x31:1,0x32:2,0x33:3,0x34:4,0x35:5,0x36:6,0x37:7,0x38:8}
fader_index_to_track_note = {0:0x64,1:0x65,2:0x66,3:0x67,4:0x68,5:0x69,6:0x6A,7:0x6B}

STATUS_PORT = 9002
_status = {"eos_connected": False, "qlab_reachable": False, "fader_mode": "submaster", "apc_connected": False}
_fire_callback = None

class StatusHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/status":
            data = json.dumps(_status).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", len(data))
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_response(404)
            self.end_headers()
    def do_POST(self):
        if self.path == "/fire":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            try:
                req = json.loads(body)
                osc = req.get("osc")
                target = req.get("target", "eos")
                use_val = req.get("use_val", True)
                if osc and _fire_callback:
                    _fire_callback(osc, target, use_val)
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(b'{"ok":true}')
            except Exception as e:
                self.send_response(500)
                self.end_headers()
        elif self.path == "/reload":
            script = "sleep 2 && launchctl unload /Users/sandalphon/Library/LaunchAgents/com.eos.apcfeedback.plist && sleep 2 && launchctl load /Users/sandalphon/Library/LaunchAgents/com.eos.apcfeedback.plist"
            subprocess.Popen(["bash", "-c", script], close_fds=True, start_new_session=True)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
        else:
            self.send_response(404)
            self.end_headers()
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
    def log_message(self, format, *args):
        pass

def start_status_server():
    try:
        srv = HTTPServer(("127.0.0.1", STATUS_PORT), StatusHandler)
        log.info("[STATUS] HTTP server on port " + str(STATUS_PORT))
        srv.serve_forever()
    except Exception as e:
        log.warning("[STATUS] Could not start: " + str(e))

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
        if "APC mini mk2".lower() in name.lower():
            return name
    return None

def find_apc_in():
    for name in mido.get_input_names():
        if "APC mini mk2".lower() in name.lower():
            return name
    return None

def load_config():
    if not os.path.exists(CONFIG_FILE):
        log.error("[CFG] Not found: " + CONFIG_FILE)
        raise SystemExit(1)
    with open(CONFIG_FILE) as f:
        cfg = json.load(f)
    log.info("[CFG] Loaded: " + CONFIG_FILE)
    net = cfg.get("network", {})
    EOS_IP = net.get("eos_ip", "2.0.0.1")
    EOS_OSC_PORT = net.get("eos_osc_port", 8000)
    QLAB_IP = net.get("qlab_ip", "2.0.0.2")
    QLAB_OSC_PORT = net.get("qlab_osc_port", 53000)
    LISTEN_PORT = net.get("listen_port", 9001)
    BUTTON_MAP = {}
    for note_str, d in cfg.get("grid_buttons", {}).items():
        BUTTON_MAP[int(note_str)] = (
            d.get("label",""), d.get("color",0), d.get("group","command"),
            d.get("osc",None), d.get("target","eos"), d.get("use_val",True))
    RC_MAP = {}
    for note_str, d in cfg.get("right_column", {}).items():
        RC_MAP[int(note_str)] = (d.get("label",""), d.get("osc",None), d.get("use_val",True))
    ML_PARAMS = {}
    for idx_str, d in cfg.get("ml_params", {}).items():
        ML_PARAMS[int(idx_str)] = (d.get("name","intens"), d.get("is_switch",False), d.get("min",0.0), d.get("max",100.0))
    COLOR_PARAMS = {}
    for idx_str, val in cfg.get("color_params", {}).items():
        COLOR_PARAMS[int(idx_str)] = val
    RIGHT_COLUMN_NOTES = sorted(RC_MAP.keys())
    return (EOS_IP, EOS_OSC_PORT, QLAB_IP, QLAB_OSC_PORT, LISTEN_PORT,
            BUTTON_MAP, RC_MAP, ML_PARAMS, COLOR_PARAMS, RIGHT_COLUMN_NOTES)

def send_led(port, note, color, channel=CH_FULL):
    port.send(mido.Message("note_on", channel=channel, note=note, velocity=color))

def send_peripheral_led(port, note, state):
    port.send(mido.Message("note_on", channel=0, note=note, velocity=state))

def grid_note(row, col):
    return (7 - row) * 8 + col

def self_test(port):
    log.info("[TEST] Starting")
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
    log.info("[TEST] Done")

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
    log.info("[ANIM] HELLO done")

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
        if target == "qlab":
            qlab_client.send_message(osc_cmd, 1 if press else 0)
        else:
            if use_val:
                eos_client.send_message(osc_cmd, 1 if press else 0)
            elif press:
                eos_client.send_message(osc_cmd, [])
        log.info("[OSC->" + target + "] " + osc_cmd)
    except Exception as e:
        log.error("[ERROR] " + str(e))

def main():
    (EOS_IP, EOS_OSC_PORT, QLAB_IP, QLAB_OSC_PORT, LISTEN_PORT,
     BUTTON_MAP, RC_MAP, ML_PARAMS, COLOR_PARAMS, RIGHT_COLUMN_NOTES) = load_config()
    log.info("Bridge v16.0 starting - with auto-reconnect")

    eos_client = udp_client.SimpleUDPClient(EOS_IP, EOS_OSC_PORT)
    qlab_client = udp_client.SimpleUDPClient(QLAB_IP, QLAB_OSC_PORT)

    global _fire_callback
    def _do_fire(osc, target, use_val):
        try:
            if target == "qlab":
                qlab_client.send_message(osc, 1)
            else:
                if use_val:
                    eos_client.send_message(osc, 1)
                else:
                    eos_client.send_message(osc, [])
            log.info("[WEB FIRE] " + osc)
        except Exception as e:
            log.error("[WEB FIRE ERROR] " + str(e))
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
        log.info("[OSC] Blind " + ("ON" if blind_active else "OFF"))

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
                        log.warning("[WATCHDOG] APC disconnected - will retry in 2s")
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

if __name__ == "__main__":
    main()
