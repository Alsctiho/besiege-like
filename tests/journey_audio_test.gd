extends SceneTree

var failures := 0
var checks := 0
var level: CoreJourney
var output := ""
var recording: AudioEffectRecord
var recording_index := -1

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--audio-output="): output = argument.trim_prefix("--audio-output=")
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--journey-verify"):
		push_error("Audio test requires isolated progress mode")
		quit(1)
		return
	if not output.is_empty():
		recording = AudioEffectRecord.new()
		recording.format = AudioStreamWAV.FORMAT_16_BITS
		recording_index = AudioServer.get_bus_effect_count(0)
		AudioServer.add_bus_effect(0, recording)
		recording.set_recording_active(true)
	level = CoreJourney.new()
	root.add_child(level)
	await _hold(0.3)
	var audio := level.audio
	_check(audio.music.playing and (audio.music.stream as AudioStreamOggVorbis).loop, "music_plays_and_loops")
	_check(absf(audio.music.stream.get_length()-60.0) < 0.01, "music_uses_original_sixty_second_track")
	_check(audio.listener.is_current(), "spatial_listener_follows_player")
	_check(audio.wheels.size() == 4, "four_separate_wheel_sounds")
	await _tap(KEY_TAB)
	_check(audio.music.playing, "assembly_does_not_restart_music")
	await _hold(0.4)
	_check(audio.music.volume_db < -8, "assembly_ducks_music")
	await _tap(KEY_TAB)
	_key(KEY_W, true)
	await _hold(0.6)
	var playing := 0
	for voice: AudioStreamPlayer3D in audio.wheels.values():
		if voice.playing: playing += 1
	_check(playing == 4, "ground_motion_plays_four_wheel_loops")
	_key(KEY_W, false)
	await _hold(1.0)
	playing = 0
	for voice: AudioStreamPlayer3D in audio.wheels.values():
		if voice.playing: playing += 1
	_check(playing == 0, "stopped_wheels_stop_looping")
	level.player.loadout.acquire("audio_rotor", "rotor")
	level.player.loadout.acquire("audio_blower", "blower")
	level.player.loadout.install("top", "audio_rotor", "top")
	level.player.loadout.install("back", "audio_blower", "back")
	await _hold(0.1)
	_key(KEY_X, true)
	await _hold(0.5)
	_check(audio.loops.back.voice.playing and audio.loops.back.active, "blower_plays_while_activated")
	_check(audio.loops.back.voice.global_position.distance_to(audio._component_position("back")) < 0.02, "sound_origin_is_component_mount")
	_key(KEY_X, false)
	await _hold(0.5)
	_check(not audio.loops.back.voice.playing, "blower_release_fades_to_stop")
	_key(KEY_SPACE, true)
	await _hold(0.2)
	var count: int = audio.event_counts.get("rotor_start", 0)
	_key(KEY_UP, true)
	await _hold(0.1)
	_check(int(audio.event_counts.get("rotor_start", 0)) == count and count > 0, "aliases_do_not_duplicate_audio_start")
	_key(KEY_SPACE, false)
	await _hold(0.1)
	_check(audio.loops.top.voice.playing, "one_alias_release_keeps_loop")
	_key(KEY_UP, false)
	await _hold(0.7)
	_check(not audio.loops.top.voice.playing and audio.event_counts.get("rotor_stop", 0) == 1, "last_alias_release_plays_stop_once")
	level.player.respawn()
	level.world.activate_bridge()
	await _hold(0.3)
	_check(is_instance_valid(audio._bridge_loop) and audio._bridge_loop.playing, "bridge_motion_has_loop")
	await _hold(2.0)
	_check(audio.event_counts.get("bridge_start", 0) == 1 and audio.event_counts.get("bridge_arrived", 0) == 1, "bridge_audio_follows_start_and_arrival")
	level.world.activate_bridge()
	_check(audio.event_counts.get("bridge_start", 0) == 1, "already_active_bridge_does_not_repeat_sound")
	level.player.position = Vector3(0, 5, 3)
	level.player.velocity = Vector3.ZERO
	await _hold(1.1)
	_check(audio.event_counts.get("wheel_landing", 0) > 0, "landing_has_single_feedback")
	level.player.loadout.remove("back")
	await _hold(0.1)
	_check(not audio.loops.has("back"), "removed_component_removes_loop")
	var paused_before := paused
	await _tap(KEY_ESCAPE)
	_check(level.hud.journey_menu.visible, "menu_exposes_audio_controls")
	var music_slider := level.hud.journey_menu.find_child("Volume_music", true, false) as HSlider
	var sfx_slider := level.hud.journey_menu.find_child("Volume_sfx", true, false) as HSlider
	_check(music_slider != null and sfx_slider != null, "separate_music_and_sfx_sliders")
	music_slider.value = 0
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(audio.MUSIC_BUS)) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(audio.SFX_BUS)), "music_mutes_independently")
	music_slider.value = 72
	sfx_slider.value = 0
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(audio.SFX_BUS)) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(audio.MUSIC_BUS)), "sfx_mutes_independently")
	sfx_slider.value = 70
	await _tap(KEY_ESCAPE)
	_check(paused == paused_before, "audio_menu_preserves_pause_flow")
	audio.music.seek(59.75)
	await _hold(0.6)
	if not output.is_empty(): _check(audio.music.get_playback_position() < 1.0, "music_wraps_without_restarting_scene")
	if recording != null:
		recording.set_recording_active(false)
		var sample := recording.get_recording()
		_check(sample != null and sample.data.size() > 48000, "real_audio_mixer_recorded_samples")
		if sample != null: _check(sample.save_to_wav(output.path_join("audio-mix.wav")) == OK, "save_real_mixer_output")
		AudioServer.remove_bus_effect(0, recording_index)
	level.queue_free()
	await process_frame
	print("JOURNEY_AUDIO_COMPLETE checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func _hold(seconds: float) -> void:
	await create_timer(seconds).timeout

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _tap(key: Key) -> void:
	_key(key, true)
	await process_frame
	await process_frame
	_key(key, false)
	await process_frame
	await process_frame

func _check(passed: bool, label: String) -> void:
	checks += 1
	print("JOURNEY_AUDIO ", "PASS " if passed else "FAIL ", label)
	if not passed:
		failures += 1
		push_error("JourneyAudioTest: " + label)
