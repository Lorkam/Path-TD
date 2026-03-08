extends Camera3D

var vitesse_camera = GameData.camera["vitesse_camera"]
var vitesse_zoom = GameData.camera["vitesse_zoom"]

var dernier_temps_usec = 0

func _ready():
	# On enregistre l'heure exacte en microsecondes
	dernier_temps_usec = Time.get_ticks_usec()

func _process(_delta):
	# --- CALCUL DU VRAI DELTA (Ultra précis) ---
	var temps_actuel = Time.get_ticks_usec()
	var unscaled_delta = (temps_actuel - dernier_temps_usec) / 1000000.0
	dernier_temps_usec = temps_actuel
	
	# Sécurité : Si l'ordinateur a un coup de lag, on empêche la caméra de se téléporter
	if unscaled_delta > 0.1:
		unscaled_delta = 0.016
	
	# --- DÉPLACEMENT ---
	var direction_cam = Vector3.ZERO
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP): direction_cam.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction_cam.z += 1
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT): direction_cam.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction_cam.x += 1
	
	if direction_cam != Vector3.ZERO:
		direction_cam = direction_cam.normalized()
		# On utilise NOTRE unscaled_delta indépendant du temps du jeu
		global_position.x += direction_cam.x * vitesse_camera * unscaled_delta
		global_position.z += direction_cam.z * vitesse_camera * unscaled_delta

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
