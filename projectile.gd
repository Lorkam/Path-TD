extends Node3D

var cible: Node3D
var degats: int
var rayon_explosion: float = 0.0 # <--- NOUVELLE VARIABLE
var vitesse = 20.0
var explosion_scene = preload("res://explosion.tscn")

func _process(delta):
	if not is_instance_valid(cible) or cible.est_mort:
		queue_free()
		return
		
	var cible_pos = cible.global_position
	# On vise un peu en l'air (le torse) au lieu de viser les pieds
	cible_pos.y += 0.5 
	
	# --- CORRECTION : On oriente le projectile vers la cible ! ---
	if global_position.distance_to(cible_pos) > 0.05:
		look_at(cible_pos, Vector3.UP)
	
	var direction = global_position.direction_to(cible_pos)
	global_position += direction * vitesse * delta
	
	# Quand le projectile touche la cible
	if global_position.distance_to(cible_pos) < 0.5:
		infliger_degats()
		queue_free()

func infliger_degats():
	# S'il y a un rayon d'explosion (Le Canon)
	if rayon_explosion > 0.0:
		
		# --- NOUVEAU : On invoque l'effet visuel d'explosion ---
		var expl_visuelle = explosion_scene.instantiate()
		# On la positionne à l'endroit de l'impact
		expl_visuelle.global_position = global_position
		# On adapte sa taille visuelle au rayon de dégâts
		expl_visuelle.set_rayon(rayon_explosion)
		# On l'ajoute à la carte (get_parent() car le projectile va mourir)
		get_parent().add_child(expl_visuelle)
		# -----------------------------------------------------
		# On récupère absolument TOUS les monstres du jeu
		var tous_les_ennemis = get_tree().get_nodes_in_group("ennemis")
		
		# On regarde un par un s'ils sont dans la zone
		for ennemi in tous_les_ennemis:
			if is_instance_valid(ennemi) and not ennemi.est_mort:
				# Si la distance entre l'explosion et l'ennemi est plus petite que le rayon
				if ennemi.global_position.distance_to(global_position) <= rayon_explosion:
					ennemi.prendre_degats(degats)
	
	# Si c'est un tir normal (La Baliste)
	else:
		if is_instance_valid(cible) and not cible.est_mort:
			cible.prendre_degats(degats)
