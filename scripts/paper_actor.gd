extends RefCounted
## A small CPU-skinned cutout rig: torso, two hip/knee/ankle chains, and blower.
## One textured mesh preserves all twelve costumes; stance feet follow ground travel.

const BlowerPose = preload("res://scripts/blower_pose.gd")
const SIZE := Vector2(78, 76)
const ANCHOR := Vector2(0.40, 1.0)
const NOZZLE_UV := Vector2(0.95, 0.06)
const NOZZLE_OFFSET := BlowerPose.REST_NOZZLE
const STRIDE := 42.0
const STANCE := 0.62
const COLUMNS := 14
const ROWS := 18

var travel := 0.0
var time := 0.0
var movement := 0.0
var direction := 1.0
var aim := 0.0
var motor := false
var gentle := false
var mesh := ArrayMesh.new()
var indices := PackedInt32Array()
var joints: Array[Dictionary] = []
var bones: Array[Transform2D] = []
var torso_transform := Transform2D.IDENTITY
var recoil := Vector2.ZERO


func _init() -> void:
	for row in range(ROWS):
		for column in range(COLUMNS):
			var a := row * (COLUMNS + 1) + column
			var b := a + 1
			var c := a + COLUMNS + 1
			indices.append_array(PackedInt32Array([a, b, c, b, c + 1, c]))
	update_joints()


func reset() -> void:
	travel = 0
	time = 0
	movement = 0
	direction = 1
	aim = 0
	motor = false
	update_joints()


func phase() -> float:
	return fposmod(travel * direction / STRIDE, 1.0)


func advance(displacement: float, dt: float, running_motor: bool, reduced := false, facing_override := 0.0, aim_override := NAN) -> void:
	travel += displacement
	time += dt
	if not is_zero_approx(facing_override): direction = facing_override
	elif absf(displacement) > 0.0001: direction = signf(displacement)
	if is_nan(aim_override):
		aim = move_toward(aim, direction * BlowerPose.MOVING_TILT if absf(displacement) > 0.0001 else 0.0, dt * BlowerPose.TURN_SPEED)
	else: aim = aim_override
	movement = move_toward(movement, 1.0 if absf(displacement) > 0.0001 else 0.0, dt * 10)
	motor = running_motor
	gentle = reduced
	update_joints()


func motor_offset() -> Vector2:
	if not motor: return Vector2.ZERO
	var amount := 0.13 if gentle else 0.38
	return Vector2(sin(time * TAU * 17.0), cos(time * TAU * 23.0) * 0.65) * amount


func foot_target(leg: int) -> Vector2:
	var local_phase := fposmod(phase() + leg * 0.5, 1.0)
	var stride_x: float
	var lift := 0.0
	if local_phase < STANCE:
		# A planted foot moves back exactly as far as the body moves forward.
		stride_x = (STANCE * 0.5 - local_phase) * STRIDE
	else:
		var swing := (local_phase - STANCE) / (1.0 - STANCE)
		stride_x = -cos(swing * PI) * STANCE * STRIDE * 0.5
		lift = sin(swing * PI) * 6.0
	var rest := Vector2(-10, -3) if leg == 0 else Vector2(10, -3)
	return rest + Vector2(stride_x, -lift)


func knee(hip: Vector2, ankle: Vector2) -> Vector2:
	var delta := ankle - hip
	var distance := clampf(delta.length(), 0.001, 24.99)
	var along := delta.normalized()
	var middle := distance * 0.5
	var bend := sqrt(maxf(0.0, 12.5 * 12.5 - middle * middle))
	return hip + along * middle + along.orthogonal() * bend


func update_joints() -> void:
	joints.clear()
	bones.clear()
	var bob := sin(phase() * TAU * 2) * movement * (0.25 if gentle else 0.65)
	torso_transform = Transform2D(direction * movement * -0.025, Vector2.ZERO)
	torso_transform.origin = Vector2(0, -20 + bob) - torso_transform * Vector2(0, -20)
	recoil = motor_offset()
	for leg in range(2):
		var hip := Vector2(-8, -20) if leg == 0 else Vector2(6, -20)
		var ankle := foot_target(leg)
		var bent := knee(hip, ankle)
		joints.append({"hip": hip, "knee": bent, "ankle": ankle})
		var rest_knee := Vector2(-9, -11) if leg == 0 else Vector2(8, -11)
		var rest_ankle := Vector2(-10, -3) if leg == 0 else Vector2(10, -3)
		bones.append(bone_transform(hip, rest_knee, hip, bent))
		bones.append(bone_transform(rest_knee, rest_ankle, bent, ankle))


func bone_transform(a: Vector2, b: Vector2, target_a: Vector2, target_b: Vector2) -> Transform2D:
	var axis := (b - a).normalized()
	var target_axis := (target_b - target_a).normalized()
	var ratio := target_a.distance_to(target_b) / a.distance_to(b)
	return Transform2D(target_axis * ratio, target_axis.orthogonal(), target_a) * Transform2D(axis, axis.orthogonal(), a).affine_inverse()


func leg_point(point: Vector2, uv: Vector2, leg: int) -> Vector2:
	var rest_ankle := Vector2(-10, -3) if leg == 0 else Vector2(10, -3)
	var joint: Dictionary = joints[leg]
	var thigh: Vector2 = bones[leg * 2] * point
	var shin: Vector2 = bones[leg * 2 + 1] * point
	var foot: Vector2 = point + joint.ankle - rest_ankle
	var result := thigh.lerp(shin, smoothstep(0.80, 0.90, uv.y))
	return result.lerp(foot, smoothstep(0.90, 0.97, uv.y))


func point(uv: Vector2) -> Vector2:
	var rest := (uv - ANCHOR) * SIZE
	# The barrel and supporting hands rotate around the grip, away from the face.
	var blower_weight := smoothstep(0.62 - uv.y * 0.15, 0.70 - uv.y * 0.15, uv.x) * (1.0 - smoothstep(0.69, 0.76, uv.y))
	var aimed := BlowerPose.GRIP + (rest - BlowerPose.GRIP).rotated(aim * direction - BlowerPose.ORIGINAL_ANGLE)
	var torso := (torso_transform * rest).lerp(aimed, blower_weight)
	var back := leg_point(rest, uv, 0)
	var front := leg_point(rest, uv, 1)
	var legs := back.lerp(front, smoothstep(0.40, 0.46, uv.x))
	var leg_weight := smoothstep(0.68, 0.76, uv.y) * (1.0 - smoothstep(0.69, 0.77, uv.x))
	var result := torso.lerp(legs, leg_weight * movement)
	return result + recoil * blower_weight


func nozzle() -> Vector2:
	var tip := point(NOZZLE_UV)
	return Vector2(tip.x * direction, tip.y)


func rebuild(texture: Texture2D, region: Rect2) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for row in range(ROWS + 1):
		for column in range(COLUMNS + 1):
			var uv := Vector2(float(column) / COLUMNS, float(row) / ROWS)
			var posed := point(uv)
			vertices.append(Vector3(posed.x, posed.y, 0))
			uvs.append((region.position + uv * region.size) / texture.get_size())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
