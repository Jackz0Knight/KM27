extends Node

# Audio bus + SFX rails. The autoload owns three buses (Master / Music / SFX)
# and exposes simple set_bus_volume / get_bus_volume helpers in linear 0–1
# units; the conversion to dB happens here so callers (the Settings popup,
# any future SFX trigger) stay clamp-and-fader-agnostic.
#
# Sounds are generated procedurally so the project ships zero audio assets
# while still exercising the entire pipeline — a small library of UI/game SFX
# (click, hover, page, coin, forge, sword, levelup, success, denied) is
# synthesised on first use and cached. `play(id)` is the general entry point;
# `play_click()` stays for the many existing callers. When real audio lands
# later, these can be re-wired to load from a SoundDB without touching callers.

const BUSES: Array[String] = ["Master", "Music", "SFX"]
const DEFAULT_VOLUMES: Dictionary = {
	"Master": 1.0,
	"Music": 0.8,
	"SFX": 0.9,
}
const MIN_DB: float = -60.0   # any linear value ≤ this maps to silence

var _bus_volume: Dictionary = {}    # bus name -> linear 0–1
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _sfx_cache: Dictionary = {}    # sfx id -> AudioStreamWAV


func _ready() -> void:
	# Ensure each named bus exists. The project file doesn't ship a custom
	# bus layout yet (no .tres), so we patch them in at runtime. The 0-th bus
	# is always "Master" in Godot; index lookup is cheap so we re-resolve on
	# every set_bus_volume call rather than caching indices that could drift.
	_ensure_buses()
	for name in BUSES:
		_bus_volume[name] = DEFAULT_VOLUMES.get(name, 1.0)
		_apply_bus_volume(name)

	# Build a small pool of players on the SFX bus so overlapping calls don't
	# cut each other off. Four voices is plenty for UI clicks.
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)


func _ensure_buses() -> void:
	# Master always exists. Music and SFX are added on first launch and
	# routed to Master so the master fader still attenuates them.
	for i in range(BUSES.size()):
		var name: String = BUSES[i]
		if AudioServer.get_bus_index(name) >= 0:
			continue
		AudioServer.add_bus(AudioServer.bus_count)
		var new_idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(new_idx, name)
		AudioServer.set_bus_send(new_idx, "Master")


func set_bus_volume(bus: String, linear: float) -> void:
	_bus_volume[bus] = clampf(linear, 0.0, 1.0)
	_apply_bus_volume(bus)


func get_bus_volume(bus: String) -> float:
	return float(_bus_volume.get(bus, DEFAULT_VOLUMES.get(bus, 1.0)))


func _apply_bus_volume(bus: String) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var linear: float = float(_bus_volume.get(bus, 1.0))
	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	# linear_to_db: a value of 1.0 → 0 dB; 0.5 → ~-6 dB; 0.1 → ~-20 dB.
	AudioServer.set_bus_volume_db(idx, maxf(MIN_DB, linear_to_db(linear)))


# ---------- SFX ----------

const SFX_SR: int = 44100
const SFX_IDS: Array[String] = [
	"click", "hover", "page", "coin", "forge", "sword",
	"levelup", "success", "denied",
]

# Play a named SFX (synthesised on first use, then cached). Cheap round-robin
# across the player pool so a fast volley doesn't truncate itself. Unknown ids
# fall back to the click.
func play(id: String) -> void:
	if not _sfx_cache.has(id):
		_sfx_cache[id] = _build_sfx(id)
	var stream: AudioStreamWAV = _sfx_cache[id]
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	p.stream = stream
	p.play()


# Back-compat shorthand for the many existing call sites.
func play_click() -> void:
	play("click")


func _build_sfx(id: String) -> AudioStreamWAV:
	match id:
		"hover":   return _gen_hover()
		"page":    return _gen_page()
		"coin":    return _gen_coin()
		"forge":   return _gen_forge()
		"sword":   return _gen_sword()
		"levelup": return _gen_levelup()
		"success": return _gen_success()
		"denied":  return _gen_denied()
		_:         return _gen_click()


# Pack a float buffer to a 16-bit mono SFX stream. No normalisation — each
# generator bakes its own absolute level (so a hover stays quieter than a forge
# clang); we only clamp.
func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var n: int = samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var s16: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = SFX_SR
	st.stereo = false
	st.data = data
	return st


func _buf(dur_s: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(SFX_SR * dur_s))
	b.fill(0.0)
	return b


# A short, tonal "pluck" click — quick attack, fast exponential fall, a low
# body (~880 Hz) plus a mid sparkle (~1760 Hz) for a leather-on-parchment feel.
func _gen_click() -> AudioStreamWAV:
	var s: PackedFloat32Array = _buf(0.06)
	for i in range(s.size()):
		var t: float = float(i) / SFX_SR
		var env: float = exp(-t * 70.0)
		s[i] = (sin(TAU * 880.0 * t) + 0.35 * sin(TAU * 1760.0 * t)) * env * 0.5
	return _to_wav(s)


# Hover — a whisper-quiet, higher, faster cousin of the click.
func _gen_hover() -> AudioStreamWAV:
	var s: PackedFloat32Array = _buf(0.045)
	for i in range(s.size()):
		var t: float = float(i) / SFX_SR
		var env: float = exp(-t * 95.0)
		s[i] = (sin(TAU * 1500.0 * t) + 0.3 * sin(TAU * 2250.0 * t)) * env * 0.22
	return _to_wav(s)


# Page/tab — a soft parchment "shff": low-passed noise under a bell window.
func _gen_page() -> AudioStreamWAV:
	var dur: float = 0.14
	var s: PackedFloat32Array = _buf(dur)
	var lp: float = 0.0
	for i in range(s.size()):
		var t: float = float(i) / SFX_SR
		var window: float = sin(PI * clampf(t / dur, 0.0, 1.0))   # 0 → 1 → 0
		var raw: float = randf() * 2.0 - 1.0
		lp = lp * 0.65 + raw * 0.35
		s[i] = lp * window * 0.45
	return _to_wav(s)


# Coin — a bright two-stage metallic "ch-ching" from inharmonic high partials.
func _gen_coin() -> AudioStreamWAV:
	var s: PackedFloat32Array = _buf(0.30)
	for i in range(s.size()):
		var t: float = float(i) / SFX_SR
		var e1: float = exp(-t * 22.0)
		var v: float = (sin(TAU * 2349.0 * t) * 0.6 + sin(TAU * 3520.0 * t) * 0.4 + sin(TAU * 4699.0 * t) * 0.25) * e1
		if t > 0.075:
			var t2: float = t - 0.075
			var e2: float = exp(-t2 * 26.0)
			v += (sin(TAU * 3524.0 * t2) * 0.45 + sin(TAU * 5280.0 * t2) * 0.28) * e2
		s[i] = v * 0.5
	return _to_wav(s)


# Forge — an anvil clang: noise transient + inharmonic free-bar modes + a low
# body thud.
func _gen_forge() -> AudioStreamWAV:
	var s: PackedFloat32Array = _buf(0.45)
	var base: float = 311.0
	var modes: Array = [1.0, 2.76, 5.40, 8.93]
	var mw: Array = [0.5, 0.4, 0.25, 0.15]
	for i in range(s.size()):
		var t: float = float(i) / SFX_SR
		var metal: float = 0.0
		for k in range(modes.size()):
			metal += sin(TAU * base * float(modes[k]) * t) * float(mw[k])
		metal *= exp(-t * 9.0)
		var trans: float = 0.0
		if t < 0.012:
			trans = (randf() * 2.0 - 1.0) * exp(-t * 280.0)
		var body: float = sin(TAU * 120.0 * t) * exp(-t * 17.0) * 0.5
		s[i] = (metal * 0.45 + trans * 0.8 + body) * 0.6
	return _to_wav(s)


# Sword — a clash: bright noise scrape transient + a high inharmonic ring.
func _gen_sword() -> AudioStreamWAV:
	var s: PackedFloat32Array = _buf(0.32)
	for i in range(s.size()):
		var t: float = float(i) / SFX_SR
		var scrape: float = (randf() * 2.0 - 1.0) * exp(-t * 32.0)
		var ring: float = (sin(TAU * 3100.0 * t) * 0.5 + sin(TAU * 4700.0 * t) * 0.35 + sin(TAU * 6200.0 * t) * 0.2) * exp(-t * 16.0)
		s[i] = (scrape * 0.55 + ring * 0.7) * 0.6
	return _to_wav(s)


# Level-up — a bell arpeggio up a D-major triad (D5 A5 D6 F#6).
func _gen_levelup() -> AudioStreamWAV:
	var freqs: Array = [587.33, 880.0, 1174.66, 1480.0]
	var step: float = 0.085
	var s: PackedFloat32Array = _buf(step * float(freqs.size()) + 0.4)
	for i in range(s.size()):
		var t: float = float(i) / SFX_SR
		var v: float = 0.0
		for ni in range(freqs.size()):
			var onset: float = float(ni) * step
			if t >= onset:
				var td: float = t - onset
				var env: float = exp(-td * 7.0)
				v += (sin(TAU * float(freqs[ni]) * td) + 0.3 * sin(TAU * 2.0 * float(freqs[ni]) * td)) * env
		s[i] = v * 0.32
	return _to_wav(s)


# Success — a soft two-tone rise (a perfect fifth, C5 → G5).
func _gen_success() -> AudioStreamWAV:
	var s: PackedFloat32Array = _buf(0.22)
	for i in range(s.size()):
		var t: float = float(i) / SFX_SR
		var freq: float = 523.25 if t < 0.1 else 783.99
		var local: float = t if t < 0.1 else t - 0.1
		var env: float = exp(-local * 12.0)
		s[i] = (sin(TAU * freq * local) + 0.25 * sin(TAU * 2.0 * freq * local)) * env * 0.45
	return _to_wav(s)


# Denied — a low, slightly gritty two-tone fall (a soft "no").
func _gen_denied() -> AudioStreamWAV:
	var dur: float = 0.26
	var s: PackedFloat32Array = _buf(dur)
	for i in range(s.size()):
		var t: float = float(i) / SFX_SR
		var freq: float = lerp(330.0, 233.0, clampf(t / dur, 0.0, 1.0))
		var raw: float = sin(TAU * freq * t)
		var grit: float = signf(raw) * 0.22
		var env: float = exp(-t * 7.0)
		s[i] = (raw * 0.6 + grit) * env * 0.5
	return _to_wav(s)
