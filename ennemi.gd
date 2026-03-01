extends Area3D

var type_ennemi = "standard"
var pv = 0
var pv_max = 0 # NOUVEAU
var vitesse = 0
var recompense = 0
var est_mort = false

var chemin: Array[Vector3] = []
var index_chemin = 0

@onready var jauge_pv = $ViewportPV/ProgressBar # NOUVEAU
@onready var animation_player = $Yeti/AnimationPlayer

func _ready():
	add_to_group("ennemis")
	
	pv = GameData.ennemis[type_ennemi]["pv"]
	pv_max = pv
	vitesse = GameData.ennemis[type_ennemi]["vitesse"]
	recompense = GameData.ennemis[type_ennemi]["recompense"]
	maj_barre_de_vie()
	
	var anim_marche = animation_player.get_animation("Run") 
	anim_marche.loop_mode = Animation.LOOP_LINEAR # On force l'animation à boucler !
	
	animation_player.play("Run")

func _process(delta):
	# S'il est mort, on arrête de lire le code de mouvement !
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
	if est_mort: return # S'il est déjà en train de mourir, on ignore les autres tirs
	
	pv -= montant
	maj_barre_de_vie()
	
	if pv <= 0:
		mourir()

func maj_barre_de_vie():
	# On calcule le pourcentage de vie restante (de 0 à 100)
	var pourcentage = (float(pv) / float(pv_max)) * 100.0
	jauge_pv.value = pourcentage

func mourir():
	est_mort = true
	get_tree().current_scene.gagner_or(recompense)
	
	# 1. On cache la barre de vie
	$AffichagePV.hide() 
	
	# 2. On désactive son "corps" pour que les tours tirent sur les autres
	$CollisionShape3D.set_deferred("disabled", true) 
	
	# 3. On lance l'animation de mort (Vérifie bien le nom exact, souvent "Death")
	animation_player.play("Death")
	
	# 4. LA MAGIE : On met le script en pause jusqu'à la fin de l'animation
	await animation_player.animation_finished
	
	# 5. L'animation est finie, on détruit le monstre
	queue_free()
