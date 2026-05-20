extends Node

# Audio bus + SFX rails. The autoload owns three buses (Master / Music / SFX)
# and exposes simple set_bus_volume / get_bus_volume helpers in linear 0–1
# units; the conversion to dB happens here so callers (the Settings popup,
# any future SFX trigger) stay clamp-and-fader-agnostic.
#
# Sounds are generated procedurally so the project ships zero audio assets
# while still exercising the entire pipeline — the click SFX is a 60 ms
# pluck synthesised on first use and cached. When real audio lands later,
# `play_click()` and friends can be re-wired to load from a SoundDB without
# touching any caller.

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
var _click_stream: AudioStreamWAV = null


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

# Play a UI click (procedurally generated on first use, then cached). Cheap
# round-robin across the player pool so a fast volley of clicks (e.g. dragging
# the SFX slider) doesn't truncate itself.
func play_click() -> void:
	if _click_stream == null:
		_click_stream = _generate_click()
	var p: AudioStreamPlayer = _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	p.stream = _click_stream
	p.play()


# Synthesise a short, tonal "pluck" click. 16-bit mono PCM, 60 ms total,
# exponential decay so it doesn't sound like a sine-wave beep. Frequencies
# blend a low body (~880 Hz) and a mid sparkle (~1760 Hz) for a leather-on-
# parchment feel that fits the medieval theme.
func _generate_click() -> AudioStreamWAV:
	const SAMPLE_RATE: int = 44100
	const DURATION_S: float = 0.06
	var sample_count: int = int(SAMPLE_RATE * DURATION_S)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t: float = float(i) / float(SAMPLE_RATE)
		# Exponential decay envelope — quick attack, fast fall.
		var env: float = exp(-t * 70.0)
		var body: float = sin(TAU * 880.0 * t)
		var sparkle: float = sin(TAU * 1760.0 * t) * 0.35
		var sample: float = (body + sparkle) * env * 0.55
		var s16: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
