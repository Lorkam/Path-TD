extends Node3D

var niveau = 1
var id_tour = "" 
var projectile_scene = preload("res://projectile.tscn")
var ennemis_a_portee = []
var cible_actuelle = null
var rayon_explosion = 0.0

func _ready():
	maj_stats()

func maj_stats():
	var idx = niveau - 1
	var stats = GameData.tours[id_tour]
	
	$Timer.wait_time = stats["cadence_tir"][idx]
	$ZoneDetection/CollisionShape3D.shape.radius = stats["portee"][idx]
	rayon_explosion = stats["rayon_explosion"][idx]
	
	# --- NOUVEAU : On charge le fichier audio de cette tour ---
	if has_node("SonTir"):
		var chemin_son = stats.get("sonTir", "")
		# Si le chemin n'est pas vide et que le fichier existe vraiment
		if chemin_son != "" and ResourceLoader.exists(chemin_son):
			$SonTir.stream = load(chemin_son)
		else:
			$SonTir.stream = null # Sécurité au cas où le fichier n'est pas trouvé

func _process(_delta):
	ennemis_a_portee = ennemis_a_portee.filter(func(e): return is_instance_valid(e) and not e.est_mort)
	
	if ennemis_a_portee.size() > 0:
		cible_actuelle = ennemis_a_portee[0]
		var position_regard = Vector3(cible_actuelle.global_position.x, global_position.y, cible_actuelle.global_position.z)
		look_at(position_regard, Vector3.UP)
	else:
		cible_actuelle = null

func _on_zone_detection_area_entered(area):
	if area.is_in_group("ennemis"): ennemis_a_portee.append(area)

func _on_zone_detection_area_exited(area):
	if area in ennemis_a_portee: ennemis_a_portee.erase(area)

func _on_timer_timeout():
	ennemis_a_portee = ennemis_a_portee.filter(func(e): return is_instance_valid(e))
	if ennemis_a_portee.size() > 0:
		tirer_sur(ennemis_a_portee[0])

func tirer_sur(cible_ennemie):
	var proj = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(0, 0.7, 0)
	proj.cible = cible_ennemie
	
	# Le projectile va chercher les dégâts du niveau actuel
	proj.degats = GameData.tours[id_tour]["degats"][niveau - 1]
	proj.rayon_explosion = rayon_explosion
	
	# --- NOUVEAU : On joue le son du tir ---
	if (has_node("SonTir") and $SonTir.stream != null) :
		var volumeTour = GameData.tours[id_tour].get("volume_tir", 0.0)
		var volumeGlobalTir = GameData.volumeGlobalTirTours
		$SonTir.volume_db = volumeTour + volumeGlobalTir
		$SonTir.play()
	else :
		print("Pas de son défini pour cette tour")
		
func set_surbrillance(active: bool):
	$Surbrillance.visible = active

func ameliorer():
	if niveau < 3: # 3 est le niveau max
		niveau += 1
		maj_stats() # On actualise la cadence, la portée, etc.
		
		# On fait grossir l'apparence de la tour de 20% pour montrer l'amélioration
		for enfant in get_children():
			if enfant is Node3D and not enfant.name in ["ZoneDetection", "Surbrillance"]:
				enfant.scale *= 1.2
