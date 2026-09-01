class_name HitboxTimeline
extends RefCounted
## Timeline puro da hitbox do golpe: fase + AABB por frame.
## Startup/recovery = off. Active = size/offset da tabela (ou fallback).

const PHASE_STARTUP := 0
const PHASE_ACTIVE := 1
const PHASE_RECOVERY := 2
## Folga de float32: 0.04+0.14 pode não ser 0.18.
const PHASE_EPS := 0.0001

const KIND_BASIC := &"basic"
const KIND_SKILL_1 := &"skill_1"
const KIND_SKILL_2 := &"skill_2"
const KIND_ULTIMATE := &"ultimate"


static func phase_at(timer: float, startup: float, active: float) -> int:
	var t: float = maxf(timer, 0.0)
	var su: float = maxf(startup, 0.0)
	var ac: float = maxf(active, 0.0)
	if t + PHASE_EPS < su:
		return PHASE_STARTUP
	if (t - su) + PHASE_EPS < ac:
		return PHASE_ACTIVE
	return PHASE_RECOVERY


static func is_hitbox_on(timer: float, startup: float, active: float) -> bool:
	return phase_at(timer, startup, active) == PHASE_ACTIVE


static func frame_count_of(
	sizes: PackedVector2Array,
	offsets: PackedFloat32Array,
	anim_frames: int
) -> int:
	var n: int = maxi(sizes.size(), offsets.size())
	n = maxi(n, anim_frames)
	return maxi(n, 1)


static func active_frame_index(
	timer: float,
	startup: float,
	active: float,
	frame_count: int
) -> int:
	var n: int = maxi(frame_count, 1)
	var ph: int = phase_at(timer, startup, active)
	if ph == PHASE_STARTUP:
		return 0
	if ph == PHASE_RECOVERY:
		return n - 1
	var su: float = maxf(startup, 0.0)
	var ac: float = maxf(active, 0.0)
	if ac <= 0.0001:
		return 0
	var p: float = clampf((maxf(timer, 0.0) - su) / ac, 0.0, 0.999999)
	return clampi(int(floor(p * float(n))), 0, n - 1)


static func visual_frame(
	timer: float,
	startup: float,
	active: float,
	anim_count: int
) -> int:
	var n: int = maxi(anim_count, 1)
	var ph: int = phase_at(timer, startup, active)
	if ph == PHASE_STARTUP:
		return 0
	if ph == PHASE_RECOVERY:
		return n - 1
	return active_frame_index(timer, startup, active, n)


static func sample_size(sizes: PackedVector2Array, fallback: Vector2, index: int) -> Vector2:
	if sizes.is_empty():
		return fallback
	return sizes[clampi(index, 0, sizes.size() - 1)]


static func sample_offset(offsets: PackedFloat32Array, fallback: float, index: int) -> float:
	if offsets.is_empty():
		return fallback
	return offsets[clampi(index, 0, offsets.size() - 1)]


static func resolve(
	timer: float,
	startup: float,
	active: float,
	sizes: PackedVector2Array,
	offsets: PackedFloat32Array,
	fallback_size: Vector2,
	fallback_offset: float,
	anim_frames: int = 0
) -> Dictionary:
	var n: int = frame_count_of(sizes, offsets, anim_frames)
	var idx: int = active_frame_index(timer, startup, active, n)
	return {
		"active": is_hitbox_on(timer, startup, active),
		"size": sample_size(sizes, fallback_size, idx),
		"offset_x": sample_offset(offsets, fallback_offset, idx),
		"frame_index": idx,
	}


static func tables_from_stats(stats: PlayerStats, kind: StringName, combo_index: int) -> Dictionary:
	if stats == null:
		return _pack(
			PackedVector2Array(),
			PackedFloat32Array(),
			Vector2(40.0, 30.0),
			28.0
		)
	match kind:
		KIND_SKILL_1:
			return _pack(
				stats.skill_1_hitbox_sizes,
				stats.skill_1_hitbox_offsets_x,
				stats.skill_1_hitbox_size,
				stats.skill_1_hitbox_offset_x
			)
		KIND_SKILL_2:
			return _pack(
				stats.skill_2_hitbox_sizes,
				stats.skill_2_hitbox_offsets_x,
				stats.skill_2_hitbox_size,
				stats.skill_2_hitbox_offset_x
			)
		KIND_ULTIMATE:
			return _pack(
				stats.ultimate_hitbox_sizes,
				stats.ultimate_hitbox_offsets_x,
				stats.ultimate_hitbox_size,
				stats.ultimate_hitbox_offset_x
			)
		_:
			return _basic_tables(stats, combo_index)


static func _basic_tables(stats: PlayerStats, combo_index: int) -> Dictionary:
	match clampi(combo_index, 1, 3):
		2:
			return _pack(
				stats.attack_hit2_hitbox_sizes,
				stats.attack_hit2_hitbox_offsets_x,
				stats.attack_hit2_hitbox_size,
				stats.attack_hit2_hitbox_offset_x
			)
		3:
			return _pack(
				stats.attack_hit3_hitbox_sizes,
				stats.attack_hit3_hitbox_offsets_x,
				stats.attack_hit3_hitbox_size,
				stats.attack_hit3_hitbox_offset_x
			)
		_:
			return _pack(
				stats.attack_hitbox_sizes,
				stats.attack_hitbox_offsets_x,
				stats.attack_hitbox_size,
				stats.attack_hitbox_offset_x
			)


static func _pack(
	sizes: PackedVector2Array,
	offsets: PackedFloat32Array,
	fallback_size: Vector2,
	fallback_offset: float
) -> Dictionary:
	return {
		"sizes": sizes,
		"offsets": offsets,
		"fallback_size": fallback_size,
		"fallback_offset": fallback_offset,
	}
