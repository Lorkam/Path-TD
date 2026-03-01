extends Node3D

var cible: Area3D
var vitesse = 10.0
var degats = 0

func _process(delta):
	# Si la cible existe toujours (elle n'a pas été tuée par une autre tour)
	if is_instance_valid(cible):
		# Le projectile fonce vers l'ennemi
		global_position = global_position.move_toward(cible.global_position, vitesse * delta)
		
		# S'il touche l'ennemi (distance très courte)
		if global_position.distance_to(cible.global_position) < 0.2:
			cible.prendre_degats(degats) # Fait perdre des PV
			queue_free() # Le projectile se détruit
	else:
		# Si l'ennemi est mort avant que le projectile n'arrive, le projectile disparaît
		queue_free()
