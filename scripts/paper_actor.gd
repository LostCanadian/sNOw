extends RefCounted
## Separate illustrated thighs, shins and shoes, attached through hip/knee/ankle joints.
## Rotations preserve bone lengths and artwork scale; no blended leg skinning.
const BlowerPose = preload("res://scripts/blower_pose.gd")
const SIZE := Vector2(78, 76)
const ANCHOR := Vector2(0.40, 1.0)
const NOZZLE_UV := Vector2(0.95, 0.06)
const NOZZLE_OFFSET := BlowerPose.REST_NOZZLE
const STRIDE := 29.0
const STANCE := 0.62
const COLUMNS := 14
const ROWS := 12
const BODY_CUT := 0.72
const HIPS := [Vector2(0.285,0.70), Vector2(0.44,0.70)]
const KNEES := [Vector2(0.255,0.84), Vector2(0.465,0.84)]
const ANKLES := [Vector2(0.245,0.965), Vector2(0.49,0.965)]
const LIMBS = preload("res://assets/art/caretaker_limbs.png")
# Independent artwork, not rectangles cut through the original complete legs.
const LIMB_RECTS := [
	[Rect2(-15.1,-25.0,12.2,16.0), Rect2(-14.8,-14.3,7.1,12.5), Rect2(-16.2,-7.4,15.0,7.4)],
	[Rect2(-3.0,-25.0,11.8,16.0), Rect2(1.4,-14.3,7.1,12.5), Rect2(2.0,-7.4,15.0,7.4)],
]
var limb_regions: Array[Rect2] = []
var limb_mesh := ArrayMesh.new()
var travel := 0.0
var gait_distance := 0.0
var time := 0.0
var movement := 0.0
var direction := 1.0
var aim := 0.0
var motor := false
var gentle := false
var mesh := ArrayMesh.new()
var joints: Array[Dictionary] = []
var bones: Array[Transform2D] = []
var feet: Array[Transform2D] = []
var torso_transform := Transform2D.IDENTITY
var recoil := Vector2.ZERO

func _init() -> void:
	limb_regions.assign(preload("res://scripts/limb_regions.gd").RECTS)
	update_joints()

static func rest(uv: Vector2) -> Vector2:
	return (uv - ANCHOR) * SIZE

func reset() -> void:
	travel = 0
	gait_distance = 0
	time = 0
	movement = 0
	direction = 1
	aim = 0
	motor = false
	update_joints()

func phase() -> float:
	return fposmod(gait_distance / STRIDE, 1.0)

func advance(displacement: float, dt: float, running_motor: bool, reduced := false, facing_override := 0.0, aim_override := NAN) -> void:
	travel += displacement
	gait_distance += absf(displacement)
	time += dt
	if not is_zero_approx(facing_override): direction = facing_override
	elif absf(displacement) > 0.0001: direction = signf(displacement)
	if is_nan(aim_override):
		aim = move_toward(aim, direction * BlowerPose.MOVING_TILT if absf(displacement) > 0.0001 else 0.0, dt * BlowerPose.TURN_SPEED)
	else: aim = aim_override
	movement = move_toward(movement, 1.0 if absf(displacement) > 0.0001 else 0.0, dt * 8)
	motor = running_motor
	gentle = reduced
	update_joints()

func motor_offset() -> Vector2:
	if not motor: return Vector2.ZERO
	return Vector2(sin(time * TAU * 17), cos(time * TAU * 23) * 0.65) * (0.13 if gentle else 0.38)

func foot_target(leg: int) -> Vector2:
	var local_phase := fposmod(phase() + leg * 0.5, 1.0)
	var stride_x := 0.0
	var lift := 0.0
	if local_phase < STANCE:
		stride_x = (STANCE * 0.5 - local_phase) * STRIDE
	else:
		var swing := (local_phase - STANCE) / (1 - STANCE)
		stride_x = -cos(swing * PI) * STANCE * STRIDE * 0.5
		lift = sin(swing * PI) * 3.3
	var target := Vector2(rest(HIPS[leg]).x + stride_x, rest(ANKLES[leg]).y - lift)
	return rest(ANKLES[leg]).lerp(target, movement)

func knee(hip: Vector2, ankle: Vector2, leg := 0) -> Vector2:
	var upper := rest(HIPS[leg]).distance_to(rest(KNEES[leg]))
	var lower := rest(KNEES[leg]).distance_to(rest(ANKLES[leg]))
	var delta := ankle - hip
	var distance := clampf(delta.length(), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var along := delta.normalized()
	var projection := (upper * upper - lower * lower + distance * distance) / (2 * distance)
	var bend := sqrt(maxf(0, upper * upper - projection * projection))
	return hip + along * projection + along.orthogonal() * bend

func update_joints() -> void:
	joints.clear()
	bones.clear()
	feet.clear()
	var bob := sin(phase() * TAU * 2) * movement * (0.15 if gentle else 0.4)
	torso_transform = Transform2D(movement * -0.018, Vector2.ZERO)
	torso_transform.origin = Vector2(0, movement * 3 + bob)
	recoil = motor_offset()
	for leg in range(2):
		var hip := rest(HIPS[leg]) + Vector2(0, movement * 3 + bob)
		var ankle := foot_target(leg)
		var maximum := rest(HIPS[leg]).distance_to(rest(KNEES[leg])) + rest(KNEES[leg]).distance_to(rest(ANKLES[leg])) - 0.001
		if hip.distance_to(ankle) > maximum: ankle = hip + (ankle - hip).normalized() * maximum
		var bent := knee(hip, ankle, leg)
		joints.append({"hip":hip, "knee":bent, "ankle":ankle})
		bones.append(bone_transform(rest(HIPS[leg]), rest(KNEES[leg]), hip, bent))
		bones.append(bone_transform(rest(KNEES[leg]), rest(ANKLES[leg]), bent, ankle))
		var local_phase := fposmod(phase() + leg*0.5, 1.0)
		var swing := clampf((local_phase - STANCE) / (1-STANCE),0,1)
		var shoe_angle := -sin(swing*PI) * 0.19 * movement
		var shoe := Transform2D(shoe_angle,Vector2.ZERO)
		shoe.origin = ankle - shoe * rest(ANKLES[leg])
		feet.append(shoe)

func bone_transform(a: Vector2, b: Vector2, target_a: Vector2, target_b: Vector2) -> Transform2D:
	var rotation := Transform2D((target_b - target_a).angle() - (b - a).angle(), Vector2.ZERO)
	rotation.origin = target_a - rotation * a
	return rotation

func point(uv: Vector2) -> Vector2:
	var source := rest(uv)
	if uv.y > BODY_CUT + 0.0001:
		var leg := 0 if uv.x < 0.36 else 1
		return (feet[leg] if uv.y >= 0.92 else bones[leg * 2 + (1 if uv.y >= 0.82 else 0)]) * source
	return upper_point(uv)

func upper_point(uv: Vector2) -> Vector2:
	var source := rest(uv)
	var blower_weight := smoothstep(0.62 - uv.y * 0.15, 0.70 - uv.y * 0.15, uv.x) * (1 - smoothstep(0.69, 0.76, uv.y))
	var aimed := BlowerPose.GRIP + (source - BlowerPose.GRIP).rotated(aim * direction - BlowerPose.ORIGINAL_ANGLE)
	return (torso_transform * source).lerp(aimed, blower_weight) + recoil * blower_weight

func nozzle() -> Vector2:
	var tip := point(NOZZLE_UV)
	return Vector2(tip.x * direction, tip.y)

func rebuild(texture: Texture2D, region: Rect2, body_cut := BODY_CUT) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Separate atlas pieces hinge as rigid layers. Rear leg is drawn first.
	var wardrobe_row := 0 if body_cut < 0.75 else (1 if body_cut < 0.79 else 2)
	for leg in range(2):
		for part in range(3):
			var patch: Rect2 = LIMB_RECTS[leg][part]
			var region_index := wardrobe_row*6 + part*2 + leg
			var source_region: Rect2 = limb_regions[region_index]
			var transform := feet[leg] if part == 2 else bones[leg*2+part]
			var start := vertices.size()
			for corner in [Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]:
				var posed: Vector2 = transform * (patch.position + corner*patch.size)
				vertices.append(Vector3(posed.x,posed.y,0))
				uvs.append((source_region.position+corner*source_region.size)/LIMBS.get_size())
			indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	var limb_arrays := []
	limb_arrays.resize(Mesh.ARRAY_MAX)
	limb_arrays[Mesh.ARRAY_VERTEX] = vertices
	limb_arrays[Mesh.ARRAY_TEX_UV] = uvs
	limb_arrays[Mesh.ARRAY_INDEX] = indices
	limb_mesh.clear_surfaces()
	limb_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,limb_arrays)
	vertices = PackedVector3Array()
	uvs = PackedVector2Array()
	indices = PackedInt32Array()
	var body_start := vertices.size()
	for row in range(ROWS + 1):
		for column in range(COLUMNS + 1):
			var uv := Vector2(float(column)/COLUMNS, float(row)/ROWS * body_cut)
			var posed := upper_point(uv)
			vertices.append(Vector3(posed.x,posed.y,0))
			uvs.append((region.position + uv * region.size) / texture.get_size())
	for row in range(ROWS):
		for column in range(COLUMNS):
			var a := body_start + row * (COLUMNS + 1) + column
			var c := a + COLUMNS + 1
			indices.append_array(PackedInt32Array([a,a+1,c,a+1,c+1,c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
