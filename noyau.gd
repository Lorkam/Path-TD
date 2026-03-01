extends Area3D

func _on_area_entered(area):
	if area.is_in_group("ennemis"):
		# On dit au script Main d'enlever une vie
		get_tree().current_scene.perdre_vie()
		
		# On détruit l'ennemi (il n'a pas été tué par une tour, donc pas d'argent)
		area.queue_free()
