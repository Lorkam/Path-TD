extends Area3D

var type_ennemi = ""
var pv = 0
var pv_max = 0 
var vitesse = 0
var recompense = 0
var est_mort = false

var chemin: Array[Vector3] = []
var index_chemin = 0

@onready var jauge_pv = $ViewportPV/ProgressBar 

# PLUS DE @onready var animation_player ICI !

func _ready():
	add_to_group("ennemis")
	
	pv = GameData.ennemis[type_ennemi]["pv"]
	pv_max = pv
	vitesse = GameData.ennemis[type_ennemi]["vitesse"]
	recompense = GameData.ennemis[type_ennemi]["recompense"]
	maj_barre_de_vie()
	
	# PLUS DE CODE D'ANIMATION DE MARCHE ICI 
	# (C'est main.gd qui s'en occupe maintenant !)

func _process(delta):
	if est_mort: return 
	
	if index_chemin < chemin.size():
		var cible = chemin[index_chemin]
		var cible_regard = Vector3(cible.x, global_position.y, cible.z)
		
		if global_position.distance_to(cible_regard) > 0.05:
			look_at(cible_regard, Vector3.UP)
			
		global_position = global_position.move_toward(cible, vitesse * delta)
		
		if global_position.distance_to(cible) < 0.1:
			index_chemin += 1

func prendre_degats(montant):
	if est_mort: return 
	
	pv -= montant
	maj_barre_de_vie()
	
	if pv <= 0:
		mourir()

func maj_barre_de_vie():
	var pourcentage = (float(pv) / float(pv_max)) * 100.0
	jauge_pv.value = pourcentage

func mourir():
	est_mort = true
	get_tree().current_scene.gagner_or(recompense)
	
	if has_node("AffichagePV"):
		$AffichagePV.hide() 
	
	$CollisionShape3D.set_deferred("disabled", true) 
	
	# --- NOUVEAU : RECHERCHE DYNAMIQUE DE L'ANIMATION DE MORT ---
	var a_joue_animation = false
	var lecteurs = find_children("*", "AnimationPlayer", true, false)
	
	for lecteur in lecteurs:
		if lecteur is AnimationPlayer and lecteur.has_animation("Death"):
			lecteur.play("Death")
			# On attend la fin de CE lecteur d'animation
			await lecteur.animation_finished
			a_joue_animation = true
			break
			
	# S'il n'y a pas d'animation "Death" trouvée, on attend juste un tout petit peu
	if not a_joue_animation:
		await get_tree().create_timer(0.1).timeout
	
	# On détruit le monstre
	queue_free()
