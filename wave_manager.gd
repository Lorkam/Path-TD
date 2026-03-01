extends Node

# On prévient le Main quand il se passe quelque chose d'important
signal vague_terminee
signal victoire
signal vague_demarree

var numero_vague = 1
var timer_vague = Timer.new()
var points_de_spawn_actifs = []
var ennemis_vivants = 0
var file_attente_ennemis = []
var index_spawn = 0

var main_node: Node3D # Référence au script principal pour faire spawn les ennemis

func _ready():
	add_child(timer_vague)
	timer_vague.timeout.connect(_on_timer_vague_timeout)

func initialiser(main: Node3D):
	main_node = main

func lancer_vague(points_spawn: Array):
	if numero_vague > GameData.vagues.size():
		victoire.emit()
		return
		
	points_de_spawn_actifs = points_spawn
	if points_de_spawn_actifs.is_empty(): return
		
	var configuration = GameData.vagues[numero_vague - 1]
	file_attente_ennemis.clear()
	
	for sous_groupe in configuration:
		for i in range(sous_groupe["nombre_ennemis"]):
			file_attente_ennemis.append({"type": sous_groupe["type"], "intervalle": sous_groupe["intervalle"]})
			
	index_spawn = 0
	ennemis_vivants = 0
	timer_vague.wait_time = 0.1
	timer_vague.start()
	
	vague_demarree.emit()

func _on_timer_vague_timeout():
	if file_attente_ennemis.size() > 0:
		var prochain = file_attente_ennemis.pop_front()
		var point = points_de_spawn_actifs[index_spawn]
		index_spawn = (index_spawn + 1) % points_de_spawn_actifs.size()
		
		# On demande au Main de créer le modèle 3D sur la carte
		main_node.creer_ennemi(point, prochain["type"])
		ennemis_vivants += 1
		
		if file_attente_ennemis.size() > 0:
			timer_vague.wait_time = prochain["intervalle"]
			timer_vague.start()
		else: timer_vague.stop()
	else: timer_vague.stop()

# Le Main appellera cette fonction quand un ennemi meurt
func signaler_mort_ennemi():
	ennemis_vivants -= 1
	if file_attente_ennemis.is_empty() and ennemis_vivants <= 0:
		numero_vague += 1
		if numero_vague > GameData.vagues.size():
			victoire.emit()
		else:
			vague_terminee.emit()
