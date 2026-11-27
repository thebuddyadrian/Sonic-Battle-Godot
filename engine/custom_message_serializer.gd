extends "res://addons/delta_rollback/MessageSerializer.gd"

const input_path_mapping := {
	'/root/MatchScene/TestStage/1' : 1,
	'/root/MatchScene/TestStage/2' : 2,
}

enum HeaderFlags {
	MOVE_VECTOR = 1 << 0,
	ATK_VECTOR = 1 << 1,
	THROW_VECTOR = 1 << 2,
	JUMP = 1 << 3,
	GUARD = 1 << 4,
	GRAB = 1 << 5,
	DASH = 1 << 6,
	ATTACK = 1 << 7,
	SPECIAL = 1 << 8,
}

var input_path_mapping_reverse := {}

func _init() -> void:
	for key in input_path_mapping:
		input_path_mapping_reverse[input_path_mapping[key]] = key

func serialize_input(all_input: Dictionary) -> PackedByteArray:
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.resize(16)
	
	buffer.put_u32(all_input['$'])
	buffer.put_u8(all_input.size() - 1)
	
	for path in all_input:
		if path == '$':
			continue
		buffer.put_u8(input_path_mapping[path])
		
		var header: int = 0
		
		var input: Dictionary = all_input[path]
		if input.has('move_vector'):
			header |= HeaderFlags.MOVE_VECTOR
		if input.has('atk_vector'):
			header |= HeaderFlags.ATK_VECTOR
		if input.has('throw_vector'):
			header |= HeaderFlags.THROW_VECTOR
		if input.has('jump'):
			header |= HeaderFlags.JUMP
		if input.has('guard'):
			header |= HeaderFlags.GUARD
		if input.has('grab'):
			header |= HeaderFlags.GRAB
		if input.has('dash'):
			header |= HeaderFlags.DASH
		if input.has('attack'):
			header |= HeaderFlags.ATTACK
		if input.has('special'):
			header |= HeaderFlags.SPECIAL
		
		buffer.put_u16(header)
		
		if input.has('move_vector'):
			var input_vector: Vector2 = input['move_vector']
			buffer.put_float(input_vector.x)
			buffer.put_float(input_vector.y)
		if input.has('atk_vector'):
			var input_vector: Vector2 = input['atk_vector']
			buffer.put_float(input_vector.x)
			buffer.put_float(input_vector.y)
		if input.has('throw_vector'):
			var input_vector: Vector2 = input['throw_vector']
			buffer.put_float(input_vector.x)
			buffer.put_float(input_vector.y)
		if input.has('jump'):
			buffer.put_u8(int(input['jump']))
		if input.has('guard'):
			buffer.put_u8(int(input['guard']))
		if input.has('grab'):
			buffer.put_u8(int(input['grab']))
		if input.has('dash'):
			buffer.put_u8(int(input['dash']))
		if input.has('attack'):
			buffer.put_u8(int(input['attack']))
		if input.has('special'):
			buffer.put_u8(int(input['special']))
		
	buffer.resize(buffer.get_position())
	return buffer.data_array

func unserialize_input(serialized: PackedByteArray) -> Dictionary:
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.put_data(serialized)
	buffer.seek(0)
	
	var all_input: Dictionary = {}
	
	all_input['$'] = buffer.get_u32()
	var input_count = buffer.get_u8()
	
	if input_count == 0:
		return all_input
	
	var path = input_path_mapping_reverse[buffer.get_u8()]
	var input := {}
	
	var header = buffer.get_u16()
	
	if header & HeaderFlags.MOVE_VECTOR:
		input["move_vector"] = Vector2(buffer.get_float(), buffer.get_float())
	if header & HeaderFlags.ATK_VECTOR:
		input["atk_vector"] = Vector2(buffer.get_float(), buffer.get_float())
	if header & HeaderFlags.THROW_VECTOR:
		input["throw_vector"] = Vector2(buffer.get_float(), buffer.get_float())
	if header & HeaderFlags.JUMP:
		input["jump"] = buffer.get_u8()
	if header & HeaderFlags.GUARD:
		input["guard"] = buffer.get_u8()
	if header & HeaderFlags.GRAB:
		input["grab"] = buffer.get_u8()
	if header & HeaderFlags.DASH:
		input["dash"] = buffer.get_u8()
	if header & HeaderFlags.ATTACK:
		input["attack"] = buffer.get_u8()
	if header & HeaderFlags.SPECIAL:
		input["special"] = buffer.get_u8()
	
	all_input[path] = input
	
	return all_input
