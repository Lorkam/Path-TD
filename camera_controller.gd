extends Camera3D

var vitesse_camera = GameData.camera["vitesse_camera"]
var vitesse_zoom = GameData.camera["vitesse_zoom"]

func _process(delta):
	# Déplacement ZQSD
	var direction_cam = Vector3.ZERO
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP): direction_cam.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction_cam.z += 1
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT): direction_cam.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction_cam.x += 1
	
	if direction_cam != Vector3.ZERO:
		direction_cam = direction_cam.normalized()
		global_position.x += direction_cam.x * vitesse_camera * delta
		global_position.z += direction_cam.z * vitesse_camera * delta

func _unhandled_input(event):
	# Zoom avec la molette
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var futurePosition = position + transform.basis.z * -vitesse_zoom
			if futurePosition.y >= GameData.camera["hauteur_min"]:
				position = futurePosition
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var futurePosition = position + transform.basis.z * vitesse_zoom
			if futurePosition.y <= GameData.camera["hauteur_max"]:
				position = futurePosition
