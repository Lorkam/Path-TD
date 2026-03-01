extends Node3D

var niveau = 1
var id_tour = "basique"
var type_tour = "basique"
var projectile_scene = preload("res://projectile.tscn")
var ennemis_a_portee = []
var cible_actuelle = null

func _ready():
	# 1. On règle la cadence de tir
	$Timer.wait_time = GameData.tours[type_tour]["cadence_tir"]
	
	# 2. On ajuste la taille du radar (la portée)
	$ZoneDetection/CollisionShape3D.shape.radius = GameData.tours[type_tour]["portee"]

func _process(_delta):
	# 1. On nettoie la liste (au cas où un ennemi est mort avant de sortir de la zone)
	ennemis_a_portee = ennemis_a_portee.filter(func(e): return is_instance_valid(e) and not e.est_mort)
	
	# 2. S'il y a des ennemis, on cible le premier entré dans la zone
	if ennemis_a_portee.size() > 0:
		cible_actuelle = ennemis_a_portee[0]
		
		# 3. La rotation ! (On garde la hauteur Y de la tour pour qu'elle reste bien droite)
		var position_regard = Vector3(cible_actuelle.global_position.x, global_position.y, cible_actuelle.global_position.z)
		
		# On tourne la tour entière vers cette position
		look_at(position_regard, Vector3.UP)
		
	else:
		cible_actuelle = null

func _on_zone_detection_area_entered(area):
	# Si ce qui entre dans le radar a l'étiquette "ennemis"
	if area.is_in_group("ennemis"):
		ennemis_a_portee.append(area)

func _on_zone_detection_area_exited(area):
	# Si l'ennemi sort de la zone, on l'oublie
	if area in ennemis_a_portee:
		ennemis_a_portee.erase(area)

func _on_timer_timeout():
	# Nettoie la liste (si un ennemi est mort dans la zone)
	ennemis_a_portee = ennemis_a_portee.filter(func(e): return is_instance_valid(e))
	
	# S'il y a au moins un ennemi, on tire sur le premier de la liste
	if ennemis_a_portee.size() > 0:
		tirer_sur(ennemis_a_portee[0])

func tirer_sur(cible_ennemie):
	var proj = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(0, 0.7, 0)
	proj.cible = cible_ennemie
	# 3. On transmet les dégâts au projectile
	proj.degats = GameData.tours[type_tour]["degats"]

func set_surbrillance(active: bool):
	$Surbrillance.visible = active

func ameliorer():
	niveau += 1
	# On booste les stats (ex: +1 dégât, cadence plus rapide)
	$Timer.wait_time *= 0.8 
	# Tu peux aussi changer sa couleur ou sa taille pour montrer qu'elle est niveau 2 !
	scale = Vector3(1.2, 1.2, 1.2)
