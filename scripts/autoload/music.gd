extends Node

# Procedural medieval music. No audio assets ship with the project — this
# mirrors MasterAudio's "synthesise it, exercise the whole pipeline, commit no
# binaries" ethos (see master_audio.gd header). Each track is a short modal
# loop built once on first request from:
#   • Karplus–Strong plucked "lute" strings (naturally decaying, string-like),
#   • a soft sustained open-fifth drone (the medieval bedrock), and
#   • a seam crossfade so the WAV loops without a click.
# It is cached and played on the Music bus, so the Settings "Music" fader
# already controls its level for free.
#
# Composition is FULLY DETERMINISTIC via a local LCG (_rnd) — it deliberately
# does NOT touch the RNG autoload, so the music sounds identical every launch
# and never perturbs gameplay seed reproducibility.
#
# Everything tuneable lives in the two _render_* composers and the constants
# below: tempo, mode, note lists, voice gains, drone weight, string damping.

const SR: int = 22050          # mono mix rate — plenty for plucked strings
const XFADE_S: float = 0.45    # loop-seam crossfade length
const TAIL_S: float = 0.7      # extra render past the loop so notes ring into the fade

var _player: AudioStreamPlayer = null
var _cache: Dictionary = {}    # track id -> AudioStreamWAV
var _current: String = ""
var _lcg: int = 1              # local PRNG state (NOT the RNG autoload)


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)


# ---------- public API ----------

func play_menu() -> void:
	_play("menu")


func play_gameplay() -> void:
	_play("gameplay")


func stop() -> void:
	if _player != null:
		_player.stop()
	_current = ""


func _play(id: String) -> void:
	if _player == null:
		return
	if _current == id and _player.playing:
		return
	_current = id
	if not _cache.has(id):
		_cache[id] = _render(id)
	_player.stream = _cache[id]
	_player.play()


# ---------- rendering ----------

func _render(id: String) -> AudioStreamWAV:
	match id:
		"gameplay":
			return _render_gameplay()
		_:
			return _render_menu()


# "The Waiting Hall" — slow, stately, D Dorian (the classic medieval mode),
# 3/4 at 66 BPM, eight bars. Lute melody arcs up and falls back to the tonic
# over a D–A open-fifth drone and a one-pluck-per-bar bass.
func _render_menu() -> AudioStreamWAV:
	_lcg = 0x13572468
	var bpm: float = 66.0
	var beat: float = 60.0 / bpm
	var loop_beats: float = 24.0                  # 8 bars × 3
	var loop_samples: int = int(loop_beats * beat * SR)
	var buf: PackedFloat32Array = _new_buf(loop_samples + int(SR * (XFADE_S + TAIL_S)))

	_drone_into(buf, _midi(38), 0.16)             # D2
	_drone_into(buf, _midi(45), 0.11)             # A2 — open fifth

	# Bass: one note per bar (3 beats). D D A G F D G D.
	var bass: Array = [[50, 3], [50, 3], [57, 3], [55, 3], [53, 3], [50, 3], [55, 3], [50, 3]]
	_lay_voice(buf, bass, beat, 0.50, 0.992, 1.2)

	# Melody (D Dorian): a rising-then-settling line.
	var mel: Array = [
		[69, 1], [67, 1], [65, 1],  [62, 2], [69, 1],  [72, 1], [71, 1], [69, 1],  [67, 3],
		[65, 1], [67, 1], [69, 1],  [74, 2], [72, 1],  [71, 1], [69, 1], [67, 1],  [62, 3],
	]
	_lay_voice(buf, mel, beat, 0.42, 0.996, 1.6)

	return _finish(buf, loop_samples)


# "The Long Campaign" — steadier, A Aeolian (natural minor), 4/4 at 88 BPM,
# eight bars of flowing eighth-notes over an A–E drone. The during-play loop.
func _render_gameplay() -> AudioStreamWAV:
	_lcg = 0x2468ACE0
	var bpm: float = 88.0
	var beat: float = 60.0 / bpm
	var loop_beats: float = 32.0                  # 8 bars × 4
	var loop_samples: int = int(loop_beats * beat * SR)
	var buf: PackedFloat32Array = _new_buf(loop_samples + int(SR * (XFADE_S + TAIL_S)))

	_drone_into(buf, _midi(33), 0.14)             # A1
	_drone_into(buf, _midi(40), 0.10)             # E2 — open fifth

	# Bass: one root per bar. A F G A | A F E A  (i–VI–VII–i …).
	var bass: Array = [[45, 4], [41, 4], [43, 4], [45, 4], [45, 4], [41, 4], [40, 4], [45, 4]]
	_lay_voice(buf, bass, beat, 0.48, 0.991, 1.1)

	# Melody (A Aeolian): A B C D E F G.
	var mel: Array = [
		[64, 0.5], [69, 0.5], [67, 0.5], [64, 0.5], [65, 1], [64, 1],
		[62, 0.5], [64, 0.5], [62, 0.5], [60, 0.5], [62, 1], [57, 1],
		[60, 0.5], [64, 0.5], [62, 0.5], [60, 0.5], [59, 1], [55, 1],
		[57, 2], [64, 1], [57, 1],
		[69, 0.5], [72, 0.5], [69, 0.5], [67, 0.5], [65, 1], [64, 1],
		[62, 0.5], [65, 0.5], [64, 0.5], [62, 0.5], [60, 1], [62, 1],
		[64, 0.5], [62, 0.5], [60, 0.5], [59, 0.5], [57, 1], [59, 1],
		[57, 2], [60, 1], [64, 1],
	]
	_lay_voice(buf, mel, beat, 0.38, 0.996, 1.5)

	return _finish(buf, loop_samples)


# ---------- synthesis primitives ----------

func _midi(n: int) -> float:
	return 440.0 * pow(2.0, (float(n) - 69.0) / 12.0)


# Deterministic 0..1 PRNG — a plain LCG kept local to this autoload so the
# music never consumes the gameplay RNG stream.
func _rnd() -> float:
	_lcg = (_lcg * 1103515245 + 12345) & 0x7FFFFFFF
	return float(_lcg) / 2147483647.0


func _new_buf(n: int) -> PackedFloat32Array:
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(n)
	b.fill(0.0)
	return b


# One Karplus–Strong plucked note: a noise-filled delay line low-pass-fed back
# on itself, which rings like a string and decays on its own. `decay` (<1)
# damps the sustain; lower notes (longer delay line) naturally ring longer.
func _pluck(freq: float, dur_s: float, decay: float) -> PackedFloat32Array:
	var n: int = int(SR * dur_s)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var p: int = maxi(2, int(round(float(SR) / freq)))
	var line: PackedFloat32Array = PackedFloat32Array()
	line.resize(p)
	for i in range(p):
		line[i] = _rnd() * 2.0 - 1.0
	var idx: int = 0
	for i in range(n):
		var nxt: int = (idx + 1) % p
		var v: float = line[idx]
		line[idx] = decay * 0.5 * (v + line[nxt])
		out[i] = v
		idx = nxt
	# Short attack ramp so the raw noise burst doesn't click on.
	var atk: int = mini(n, int(SR * 0.006))
	for i in range(atk):
		out[i] *= float(i) / float(atk)
	return out


# Sustained drone across the whole buffer: fundamental + a couple of soft
# overtones, with a slow tremolo swell so it breathes rather than sits dead.
func _drone_into(dst: PackedFloat32Array, freq: float, gain: float) -> void:
	var n: int = dst.size()
	for i in range(n):
		var t: float = float(i) / float(SR)
		var trem: float = 0.80 + 0.20 * sin(TAU * 0.10 * t)
		var s: float = sin(TAU * freq * t)
		s += 0.35 * sin(TAU * freq * 2.0 * t)
		s += 0.12 * sin(TAU * freq * 3.0 * t)
		dst[i] += s * gain * trem


# Schedule a monophonic voice (melody or bass) onto the buffer. `notes` is an
# array of [midi, beats]; midi <= 0 is a rest. `ring` lets each note sound past
# its slot for a legato, overlapping-lute feel.
func _lay_voice(dst: PackedFloat32Array, notes: Array, beat_dur: float, gain: float, decay: float, ring: float) -> void:
	var cursor: int = 0
	for note in notes:
		var m: int = int(note[0])
		var beats: float = float(note[1])
		var slot: int = int(beats * beat_dur * float(SR))
		if m > 0:
			var dur: float = beats * beat_dur * ring
			var pl: PackedFloat32Array = _pluck(_midi(m), dur, decay)
			_mix_into(dst, pl, cursor, gain)
		cursor += slot


func _mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, start: int, gain: float) -> void:
	var n: int = src.size()
	var cap: int = dst.size()
	for i in range(n):
		var di: int = start + i
		if di >= cap:
			break
		dst[di] += src[i] * gain


# Crossfade the post-loop tail back over the head (so the seam is continuous),
# normalise to a safe peak, and pack to a looping 16-bit mono WAV.
func _finish(buf: PackedFloat32Array, loop_samples: int) -> AudioStreamWAV:
	var xf: int = int(SR * XFADE_S)
	var final: PackedFloat32Array = PackedFloat32Array()
	final.resize(loop_samples)
	for i in range(loop_samples):
		final[i] = buf[i]
	for i in range(xf):
		if loop_samples + i >= buf.size():
			break
		var a: float = float(i) / float(xf)        # head weight rises 0 -> 1
		final[i] = buf[i] * a + buf[loop_samples + i] * (1.0 - a)

	var peak: float = 0.0001
	for i in range(loop_samples):
		peak = maxf(peak, absf(final[i]))
	var norm: float = 0.85 / peak

	var data: PackedByteArray = PackedByteArray()
	data.resize(loop_samples * 2)
	for i in range(loop_samples):
		var s16: int = clampi(int(final[i] * norm * 32767.0), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	var st: AudioStreamWAV = AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = SR
	st.stereo = false
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = loop_samples
	st.data = data
	return st
