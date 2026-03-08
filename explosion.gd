extends Node3D

@onready var particules = $GPUParticles3D

func _ready():
	# On force l'émission des particules au démarrage
	particules.emitting = true
	
	# La magie de Godot 4 : on attend la fin de l'émission pour s'autodétruire
	particules.finished.connect(queue_free)

# Petite fonction optionnelle pour adapter la taille de l'effet visuel
# au rayon de dégâts défini dans GameData
func set_rayon(rayon: float):
	# On ajuste l'échelle globale de la scène
	scale = Vector3(rayon, rayon, rayon) * 0.5 # Le *0.5 est un ajustement esthétique
