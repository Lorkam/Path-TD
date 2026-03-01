extends Node3D

var cible: Area3D
var vitesse = 10.0
var degats = 0

func _process(delta):
	# Si la cible existe toujours (elle n'a pas été tuée par une autre tour)
	if is_instance_valid(cible):
		# Réhaussage de la cible pour que les projectiles visent le centre d'une cible et pas ses pieds
		var positionCible = cible.global_position
		positionCible.y = positionCible.y + 0.4
		
		# Le projectile fonce vers l'ennemi
		global_position = global_position.move_toward(positionCible, vitesse * delta)
		
		var position_regard = Vector3(positionCible.x, positionCible.y, positionCible.z)
		
		# On tourne la tour entière vers cette position
		look_at(position_regard, Vector3.UP)
		
		# S'il touche l'ennemi (distance très courte)
		if global_position.distance_to(positionCible) < 0.2:
			cible.prendre_degats(degats) # Fait perdre des PV
			queue_free() # Le projectile se détruit
	else:
		# Si l'ennemi est mort avant que le projectile n'arrive, le projectile disparaît
		queue_free()
