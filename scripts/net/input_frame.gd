class_name InputFrame
extends RefCounted
## Frame de input do guest → host. 4 bytes: axis i8 + held u8 + just u8 + pad.

const BIT_JUMP := 1
const BIT_DASH := 2
const BIT_ATK := 4
const BIT_S1 := 8
const BIT_S2 := 16
const BIT_ULT := 32
const BIT_PAUSE := 64

const PACK_SIZE := 4


static func just_mask_now() -> int:
	var m := 0
	if Input.is_action_just_pressed("jump"):
		m |= BIT_JUMP
	if Input.is_action_just_pressed("advance"):
		m |= BIT_DASH
	if Input.is_action_just_pressed("attack_basic"):
		m |= BIT_ATK
	if Input.is_action_just_pressed("skill_1"):
		m |= BIT_S1
	if Input.is_action_just_pressed("skill_2"):
		m |= BIT_S2
	if Input.is_action_just_pressed("ultimate"):
		m |= BIT_ULT
	if Input.is_action_just_pressed("pause"):
		m |= BIT_PAUSE
	return m


static func held_mask_now() -> int:
	var m := 0
	if Input.is_action_pressed("jump"):
		m |= BIT_JUMP
	if Input.is_action_pressed("advance"):
		m |= BIT_DASH
	if Input.is_action_pressed("attack_basic"):
		m |= BIT_ATK
	if Input.is_action_pressed("skill_1"):
		m |= BIT_S1
	if Input.is_action_pressed("skill_2"):
		m |= BIT_S2
	if Input.is_action_pressed("ultimate"):
		m |= BIT_ULT
	if Input.is_action_pressed("pause"):
		m |= BIT_PAUSE
	return m


static func axis_now() -> int:
	var axis: float = Input.get_axis("move_left", "move_right")
	return clampi(int(round(axis * 127.0)), -127, 127)


static func pack_from_local(just_or: int) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(PACK_SIZE)
	buf.encode_s8(0, axis_now())
	buf.encode_u8(1, held_mask_now() & 0xFF)
	buf.encode_u8(2, just_or & 0xFF)
	buf.encode_u8(3, 0)
	return buf


static func unpack_axis(buf: PackedByteArray) -> float:
	if buf.size() < PACK_SIZE:
		return 0.0
	return float(buf.decode_s8(0)) / 127.0


static func unpack_held(buf: PackedByteArray) -> int:
	if buf.size() < PACK_SIZE:
		return 0
	return buf.decode_u8(1)


static func unpack_just(buf: PackedByteArray) -> int:
	if buf.size() < PACK_SIZE:
		return 0
	return buf.decode_u8(2)


static func has_bit(mask: int, bit: int) -> bool:
	return (mask & bit) != 0
