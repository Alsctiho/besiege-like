class_name Sfx
extends RefCounted
## 程序化音效占位：运行时生成 16-bit PCM（射击/火箭/爆炸），空间播放。

static var _cache := {}


static func play(parent: Node, name: String, pos: Vector3) -> void:
	if parent == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(name)
	p.volume_db = 2.0
	p.max_distance = 60.0
	p.position = pos
	parent.add_child(p)
	p.play()
	p.finished.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


static func _stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var rate := 22050
	var dur := 0.4
	match name:
		"cannon":
			dur = 0.18
		"rocket":
			dur = 0.5
		"explosion":
			dur = 0.7
		_:
			dur = 0.3
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / n
		var raw := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, raw, 0.25)  # 低通，去咔哒感
		var env := pow(1.0 - t, 1.8)
		var s := lp * env
		if name == "rocket":
			s = (raw * 0.3 + sin(t * 60.0) * 0.7) * env * 0.6
		var v := int(clampf(s, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	_cache[name] = wav
	return wav
