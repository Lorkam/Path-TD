extends Node3D

@onready var camera = $Camera3D
@onready var grid_map = $GridMap
@onready var preview_grid = $PreviewGridMap
@onready var affichage_stats = $CanvasLayer/AffichageStats
@onready var menu_tours = $CanvasLayer/MenuTours
@onready var menu_principal = $CanvasLayer/MenuPrincipal
@onready var menu_game_over = $CanvasLayer/MenuGameOver
@onready var menu_victoire = $CanvasLayer/MenuVictoire
@onready var file_attente_ui = $CanvasLayer/FileAttenteUI
@onready var menu_action_tour = $CanvasLayer/MenuActionTour
@onready var btn_ameliorer = $CanvasLayer/MenuActionTour/VBoxContainer/BtnAmeliorer
@onready var btn_vendre = $CanvasLayer/MenuActionTour/VBoxContainer/BtnVendre
@onready var btn_fermer = $CanvasLayer/MenuActionTour/VBoxContainer/BtnFermer
@onready var texte_action_tour = $CanvasLayer/MenuActionTour/VBoxContainer/TexteInfo

var file_attente_patterns = [] # Remplace pattern_en_attente
var tours_sur_grille = {}      # Dictionnaire [Vector3i -> Node Tour]
var case_tour_survolee = Vector3i(999,999,999)
var case_tour_selectionnee = Vector3i(999,999,999)

var ennemi_scene = preload("res://ennemi.tscn")
var tour_scene = preload("res://tour.tscn")
var noyau_scene = preload("res://noyau.tscn")
var marqueur_scene = preload("res://marqueur_emplacement.tscn")

var astar = AStarGrid2D.new()
var sol_imaginaire = Plane(Vector3.UP, 0.5)
var index_rotation = 0
var map_rotations = [0, 22, 10, 16] # Ce sont les codes secrets de Godot pour pivoter à 0°, 90°, 180° et 270° sur l'axe Y

var vitesse_camera = GameData.camera["vitesse_camera"]
var vitesse_zoom = GameData.camera["vitesse_zoom"]

var or_joueur = GameData.or_depart
var vies_joueur = GameData.vies_depart

# NOUVEAU : Ajout des phases MENU et FIN
enum Phase { MENU, PLACEMENT, PREPARATION, COMBAT, FIN }
var phase_actuelle = Phase.MENU # Le jeu commence dans le Menu !

var numero_vague = 1
var timer_vague = Timer.new()
var points_de_spawn_actifs = []
var ennemis_vivants_sur_carte = 0
var file_attente_ennemis = []
var index_spawn_actuel = 0

var pattern_en_attente = []
var case_preview_actuelle = Vector3i(999, 999, 999)

var tour_selectionnee = ""
var mesh_preview_tour: MeshInstance3D
var noeud_marqueurs: Node3D
var emplacements_valides = []

func _ready():
	astar.region = Rect2i(-50, -50, 100, 100)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for x in range(-50, 50):
		for y in range(-50, 50):
			astar.set_point_solid(Vector2i(x, y), true)
			
	add_child(timer_vague)
	timer_vague.timeout.connect(_on_timer_vague_timeout)
	
	noeud_marqueurs = Node3D.new()
	add_child(noeud_marqueurs)
	
	mesh_preview_tour = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0.5, 1, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_preview_tour.mesh = cyl
	mesh_preview_tour.set_surface_override_material(0, mat)
	add_child(mesh_preview_tour)
	mesh_preview_tour.hide()
	
	generer_terrain_base()
	generer_menu_tours()
	
	# --- CONNEXION DES BOUTONS DES MENUS ---
	$CanvasLayer/MenuPrincipal/BoutonJouer.pressed.connect(commencer_jeu)
	$CanvasLayer/MenuPrincipal/BoutonQuitter.pressed.connect(quitter_jeu)
	$CanvasLayer/MenuGameOver/BoutonRecommencer.pressed.connect(recommencer_jeu)
	$CanvasLayer/MenuGameOver/BoutonQuitter.pressed.connect(quitter_jeu)
	$CanvasLayer/MenuVictoire/BoutonRecommencer.pressed.connect(recommencer_jeu)
	$CanvasLayer/MenuVictoire/BoutonQuitter.pressed.connect(quitter_jeu)
	
	# --- INITIALISATION DE LA FILE D'ATTENTE ---
	file_attente_patterns.clear()
	for i in range(GameData.taille_file_plateformes):
		file_attente_patterns.append(GameData.patterns_plateformes.pick_random())
		
	piocher_prochaine_plateforme() # On met la 1ère tuile dans notre main proprement !
	
	btn_fermer.pressed.connect(fermer_menu_action_tour)
	btn_ameliorer.pressed.connect(ameliorer_tour_selectionnee)
	btn_vendre.pressed.connect(vendre_tour_selectionnee)
	
	afficher_menu_principal()

# ==========================================
# GESTION DES MENUS ET DE L'ÉTAT DU JEU
# ==========================================

func afficher_menu_principal():
	phase_actuelle = Phase.MENU
	menu_principal.show()
	menu_game_over.hide()
	menu_victoire.hide()
	affichage_stats.hide()
	menu_tours.hide()

func commencer_jeu():
	phase_actuelle = Phase.PLACEMENT
	menu_principal.hide()
	affichage_stats.show()
	menu_tours.show()
	maj_emplacements_valides()
	mettre_a_jour_ui()

func declencher_game_over():
	phase_actuelle = Phase.FIN
	menu_game_over.show()
	affichage_stats.hide()
	menu_tours.hide()

func declencher_victoire():
	phase_actuelle = Phase.FIN
	menu_victoire.show()
	affichage_stats.hide()
	menu_tours.hide()

func recommencer_jeu():
	# Recharge la scène actuelle de zéro (Reset parfait !)
	get_tree().reload_current_scene()

func quitter_jeu():
	get_tree().quit()

# ==========================================
# GESTION DE L'INTERFACE ET DES TOURS
# ==========================================

func generer_menu_tours():
	for enfant in menu_tours.get_children():
		enfant.queue_free()
		
	for id_tour in GameData.tours.keys():
		var infos = GameData.tours[id_tour]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(160, 80)
		btn.text = id_tour.capitalize() + "\n🪙 " + str(infos["prix"]) + " Or"
		btn.pressed.connect(func(): selectionner_tour(id_tour))
		menu_tours.add_child(btn)

func selectionner_tour(id: String):
	if phase_actuelle == Phase.PREPARATION:
		tour_selectionnee = id
		mettre_a_jour_ui()

# ==========================================
# INPUT ET PRÉVISUALISATION
# ==========================================

func _unhandled_input(event):
	# On bloque TOUTES les commandes si on est dans un menu
	if phase_actuelle == Phase.MENU or phase_actuelle == Phase.FIN: return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var futurePosition = camera.position + camera.transform.basis.z * -vitesse_zoom
			if futurePosition.y >= GameData.camera["hauteur_min"]:
				camera.position = futurePosition
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var futurePosition = camera.position + camera.transform.basis.z * vitesse_zoom
			if futurePosition.y <= GameData.camera["hauteur_max"]:
				camera.position = futurePosition
			return
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if phase_actuelle == Phase.PREPARATION:
			tour_selectionnee = ""
			mesh_preview_tour.hide()
			mettre_a_jour_ui()
		
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos_souris = get_viewport().get_mouse_position()
		var impact = sol_imaginaire.intersects_ray(camera.project_ray_origin(pos_souris), camera.project_ray_normal(pos_souris))
		if impact == null: return
		var case_clic = grid_map.local_to_map(impact)
		
		# 1. On clique sur une tour existante !
		if case_clic in tours_sur_grille and phase_actuelle == Phase.PREPARATION:
			ouvrir_menu_action_tour(case_clic)
			return
			
		# 2. Sinon, on place une plateforme ou une tour...
		if phase_actuelle == Phase.PLACEMENT:
			if case_preview_actuelle in emplacements_valides:
				placer_zone(case_preview_actuelle)
				
		elif phase_actuelle == Phase.PREPARATION and tour_selectionnee != "":
			if grid_map.get_cell_item(case_clic) == 0 and not case_clic in tours_sur_grille:
				placer_tour(case_clic, tour_selectionnee)
				
	elif event is InputEventKey and event.keycode == KEY_R and event.pressed:
		if phase_actuelle == Phase.PLACEMENT:
			pivoter_pattern()
	
	elif event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		if phase_actuelle == Phase.PREPARATION:
			tour_selectionnee = ""
			mesh_preview_tour.hide()
			lancer_vague()

func _process(delta):
	# On bloque la caméra et la souris si on est dans un menu
	if phase_actuelle == Phase.MENU or phase_actuelle == Phase.FIN: return

	var direction_cam = Vector3.ZERO
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP): direction_cam.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction_cam.z += 1
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT): direction_cam.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction_cam.x += 1
	
	if direction_cam != Vector3.ZERO:
		direction_cam = direction_cam.normalized()
		camera.global_position.x += direction_cam.x * vitesse_camera * delta
		camera.global_position.z += direction_cam.z * vitesse_camera * delta
		
	var pos_souris = get_viewport().get_mouse_position()
	var impact = sol_imaginaire.intersects_ray(camera.project_ray_origin(pos_souris), camera.project_ray_normal(pos_souris))
	
	if impact == null: return
	
	var case_survolee = grid_map.local_to_map(impact)
	
	# --- GESTION DE LA SURBRILLANCE DES TOURS ---
	if case_survolee != case_tour_survolee:
		# On éteint l'ancienne
		if case_tour_survolee in tours_sur_grille:
			tours_sur_grille[case_tour_survolee].set_surbrillance(false)
		
		# On allume la nouvelle si c'est une tour
		if case_survolee in tours_sur_grille:
			tours_sur_grille[case_survolee].set_surbrillance(true)
			
		case_tour_survolee = case_survolee
	
	if phase_actuelle == Phase.PLACEMENT:
		var centre_x = snapped(case_survolee.x, GameData.taille_plateforme)
		var centre_z = snapped(case_survolee.z, GameData.taille_plateforme)
		var centre_snappe = Vector3i(centre_x, 0, centre_z)
		
		if centre_snappe in emplacements_valides:
			if centre_snappe != case_preview_actuelle:
				case_preview_actuelle = centre_snappe
				dessiner_preview(case_preview_actuelle)
		else:
			preview_grid.clear()
			case_preview_actuelle = Vector3i(999, 999, 999)
			
	elif phase_actuelle == Phase.PREPARATION and tour_selectionnee != "":
		if grid_map.get_cell_item(case_survolee) == 0:
			mesh_preview_tour.show()
			var pos_locale = grid_map.map_to_local(case_survolee)
			mesh_preview_tour.global_position = Vector3(pos_locale.x, 0.5, pos_locale.z)
		else:
			mesh_preview_tour.hide()

# ==========================================
# LOGIQUE DES MARQUEURS ET DE CONNEXION STRICTE
# ==========================================

func maj_emplacements_valides():
	for enfant in noeud_marqueurs.get_children(): enfant.queue_free()
	emplacements_valides.clear()
	if phase_actuelle != Phase.PLACEMENT: return
	
	var centres_a_tester = []
	for case in grid_map.get_used_cells():
		if grid_map.get_cell_item(case) > 0: # <-- CORRECTION : Si c'est un chemin (1, 2, 3 ou 4)
			var voisins = [Vector3i(case.x+1,0,case.z), Vector3i(case.x-1,0,case.z), Vector3i(case.x,0,case.z+1), Vector3i(case.x,0,case.z-1)]
			for v in voisins:
				if grid_map.get_cell_item(v) == -1:
					var centre = Vector3i(snapped(v.x, GameData.taille_plateforme), 0, snapped(v.z, GameData.taille_plateforme))
					if not centre in centres_a_tester: centres_a_tester.append(centre)
						
	for centre in centres_a_tester:
		var est_valide = est_placement_valide(centre)
		if est_valide: emplacements_valides.append(centre)
		creer_marqueur(centre, est_valide)

func creer_marqueur(centre: Vector3i, est_valide: bool):
	var marqueur = marqueur_scene.instantiate()
	noeud_marqueurs.add_child(marqueur)
	var pos_locale = grid_map.map_to_local(centre)
	marqueur.global_position = Vector3(pos_locale.x, 0.51, pos_locale.z)
	
	var couleur = Color(1, 1, 1, 0.7)
	if not est_valide: couleur = Color(1, 0, 0, 0.5)
		
	var mat_dynamique = StandardMaterial3D.new()
	mat_dynamique.albedo_color = couleur
	mat_dynamique.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_dynamique.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for enfant in marqueur.get_children():
		if enfant is MeshInstance3D: enfant.set_surface_override_material(0, mat_dynamique)

func est_placement_valide(centre: Vector3i) -> bool:
	var connecte_chemin = false
	for x in range(-2, 3):
		for z in range(-2, 3):
			var type_nouveau = pattern_en_attente[z + 2][x + 2]
			var case_absolue = Vector3i(centre.x + x, 0, centre.z + z)
			if abs(x) == 2 or abs(z) == 2:
				var voisins = [Vector3i(case_absolue.x+1,0,case_absolue.z), Vector3i(case_absolue.x-1,0,case_absolue.z), Vector3i(case_absolue.x,0,case_absolue.z+1), Vector3i(case_absolue.x,0,case_absolue.z-1)]
				for v in voisins:
					if abs(v.x - centre.x) > 2 or abs(v.z - centre.z) > 2:
						var type_ancien = grid_map.get_cell_item(v)
						if type_ancien != -1:
							# <-- CORRECTION : On compare de manière intelligente
							var ancien_est_chemin = (type_ancien > 0)
							var nouveau_est_chemin = (type_nouveau > 0)
							
							if nouveau_est_chemin != ancien_est_chemin: return false
							if nouveau_est_chemin and ancien_est_chemin: connecte_chemin = true
	return connecte_chemin

# ==========================================
# RESTE DES MÉCANIQUES (Vagues, Rotation, Pose)
# ==========================================

func pivoter_pattern():
	var nouveau_pattern = []
	for i in range(5):
		var ligne = []
		for j in range(5): ligne.append(pattern_en_attente[4 - j][i])
		nouveau_pattern.append(ligne)
	pattern_en_attente = nouveau_pattern
	
	index_rotation = (index_rotation + 1) % 4 # <-- NOUVEAU : On tourne aussi le modèle 3D
	
	maj_emplacements_valides()
	case_preview_actuelle = Vector3i(999,999,999)

func placer_zone(centre: Vector3i):
	for x in range(-2, 3):
		for z in range(-2, 3):
			var case_absolue = Vector3i(centre.x + x, 0, centre.z + z)
			var type_bloc = pattern_en_attente[z + 2][x + 2] 
			
			if type_bloc == 0:
				grid_map.set_cell_item(case_absolue, 0, 0)
				astar.set_point_solid(Vector2i(case_absolue.x, case_absolue.z), true)
			else:
				var infos = obtenir_modele_et_rotation(x + 2, z + 2, pattern_en_attente)
				grid_map.set_cell_item(case_absolue, infos["id"], map_rotations[infos["rot"]])
				astar.set_point_solid(Vector2i(case_absolue.x, case_absolue.z), false)
			
	phase_actuelle = Phase.PREPARATION
	preview_grid.clear()
	
	piocher_prochaine_plateforme() 
	maj_emplacements_valides()     
	mettre_a_jour_ui()

func dessiner_preview(centre: Vector3i):
	preview_grid.clear()
	for x in range(-2, 3):
		for z in range(-2, 3):
			var type_bloc = pattern_en_attente[z + 2][x + 2]
			
			if type_bloc == 0:
				preview_grid.set_cell_item(Vector3i(centre.x + x, 0.3, centre.z + z), 0, 0)
			else:
				var infos = obtenir_modele_et_rotation(x + 2, z + 2, pattern_en_attente)
				preview_grid.set_cell_item(Vector3i(centre.x + x, 0.3, centre.z + z), infos["id"], map_rotations[infos["rot"]])

func placer_tour(case: Vector3i, id_tour: String):
	var prix = GameData.tours[id_tour]["prix"]
	if or_joueur >= prix:
		var tour = tour_scene.instantiate()
		tour.id_tour = id_tour # On sauvegarde l'ID
		add_child(tour)
		var c = grid_map.map_to_local(case)
		tour.global_position = Vector3(c.x, 0.5, c.z)
		
		tours_sur_grille[case] = tour # NOUVEAU : On enregistre la tour dans le dico !
		
		or_joueur -= prix
		mettre_a_jour_ui()

func trouver_bouts_ouverts() -> Array:
	var bouts = []
	for case in grid_map.get_used_cells():
		if abs(case.x) <= 2 and abs(case.z) <= 2: continue
		if grid_map.get_cell_item(case) > 0:
			var voisins = [Vector3i(case.x+1,0,case.z), Vector3i(case.x-1,0,case.z), Vector3i(case.x,0,case.z+1), Vector3i(case.x,0,case.z-1)]
			for v in voisins:
				if grid_map.get_cell_item(v) == -1:
					bouts.append(case); break 
	return bouts

func lancer_vague():
	points_de_spawn_actifs = trouver_bouts_ouverts()
	if points_de_spawn_actifs.is_empty(): return
		
	var index_vague = numero_vague - 1
	var configuration_vague = GameData.vagues[index_vague]
	
	file_attente_ennemis.clear()
	for sous_groupe in configuration_vague:
		for i in range(sous_groupe["nombre_ennemis"]):
			file_attente_ennemis.append({"type": sous_groupe["type"], "intervalle": sous_groupe["intervalle"]})
			
	phase_actuelle = Phase.COMBAT
	index_spawn_actuel = 0
	timer_vague.wait_time = 0.1 
	timer_vague.start()
	mettre_a_jour_ui()

func _on_timer_vague_timeout():
	if file_attente_ennemis.size() > 0:
		var prochain_ennemi = file_attente_ennemis.pop_front()
		var point_de_spawn = points_de_spawn_actifs[index_spawn_actuel]
		index_spawn_actuel = (index_spawn_actuel + 1) % points_de_spawn_actifs.size()
		
		creer_ennemi(point_de_spawn, prochain_ennemi["type"])
		
		if file_attente_ennemis.size() > 0:
			timer_vague.wait_time = prochain_ennemi["intervalle"]
			timer_vague.start()
		else: timer_vague.stop()
	else: timer_vague.stop()

func creer_ennemi(case_depart: Vector3i, type_ennemi: String):
	var depart_2d = Vector2i(case_depart.x, case_depart.z)
	var chemin_2d = astar.get_id_path(depart_2d, Vector2i(0, 0))
	if chemin_2d.is_empty(): return
		
	var nouvel_ennemi = ennemi_scene.instantiate()
	nouvel_ennemi.type_ennemi = type_ennemi
	add_child(nouvel_ennemi)
	
	var centre_3d = grid_map.map_to_local(case_depart)
	nouvel_ennemi.global_position = Vector3(centre_3d.x, 0.5, centre_3d.z)
	
	var chemin_3d: Array[Vector3] = []
	for point in chemin_2d:
		var pos_3d = grid_map.map_to_local(Vector3i(point.x, 0, point.y))
		chemin_3d.append(Vector3(pos_3d.x, 0.5, pos_3d.z))
		
	nouvel_ennemi.chemin = chemin_3d
	ennemis_vivants_sur_carte += 1
	nouvel_ennemi.tree_exited.connect(_on_ennemi_mort)

func _on_ennemi_mort():
	ennemis_vivants_sur_carte -= 1
	if phase_actuelle == Phase.COMBAT and file_attente_ennemis.is_empty() and ennemis_vivants_sur_carte <= 0:
		terminer_vague()

func terminer_vague():
	if numero_vague >= GameData.vagues.size():
		declencher_victoire()
		return
	
	numero_vague += 1
	phase_actuelle = Phase.PLACEMENT
	
	# La pièce suivante a déjà été préparée à la fin de placer_zone() !
	maj_emplacements_valides() 
	mettre_a_jour_ui()

func generer_terrain_base():
	for x in range(-2, 3):
		for z in range(-2, 3):
			var absolue = Vector3i(x, 0, z)
			var type_bloc = GameData.pattern_base[z + 2][x + 2]
			
			if type_bloc == 0:
				grid_map.set_cell_item(absolue, 0, 0) # Herbe
				astar.set_point_solid(Vector2i(absolue.x, absolue.z), true)
			else:
				var infos = obtenir_modele_et_rotation(x + 2, z + 2, GameData.pattern_base)
				grid_map.set_cell_item(absolue, infos["id"], map_rotations[infos["rot"]])
				astar.set_point_solid(Vector2i(absolue.x, absolue.z), false)
				
	var noyau = noyau_scene.instantiate()
	add_child(noyau)
	noyau.global_position = Vector3(0.5, 0.5, 0.5)

func gagner_or(montant):
	or_joueur += montant; mettre_a_jour_ui()

func perdre_vie():
	vies_joueur -= 1; mettre_a_jour_ui()
	
	# --- NOUVEAU : VÉRIFICATION DU GAME OVER ---
	if vies_joueur <= 0:
		declencher_game_over()

func mettre_a_jour_ui():
	var texte_phase = ""
	if phase_actuelle == Phase.PLACEMENT: texte_phase = " | 🛠️ Place ta plateforme"
	elif phase_actuelle == Phase.PREPARATION: 
		if tour_selectionnee == "": texte_phase = " | 🛡️ Place tes tours (Espace = Go!)"
		else: texte_phase = " | 🎯 Pose la tour " + tour_selectionnee.capitalize() + " (Clic Droit = Annuler)"
	elif phase_actuelle == Phase.COMBAT: texte_phase = " | ⚔️ VAGUE " + str(numero_vague) + " EN COURS"
	
	affichage_stats.text = "🪙 Or : " + str(or_joueur) + "   ❤️ Vies : " + str(vies_joueur) + texte_phase
	
func piocher_prochaine_plateforme():
	pattern_en_attente = file_attente_patterns.pop_front()
	file_attente_patterns.append(GameData.patterns_plateformes.pick_random())
	
	index_rotation = 0 # <-- NOUVEAU : La nouvelle pièce piochée a une rotation de base (0)
	dessiner_file_attente_ui()

func dessiner_file_attente_ui():
	for enfant in file_attente_ui.get_children(): enfant.queue_free()
	
	file_attente_ui.add_theme_constant_override("separation", 15)
	
	# 1. AFFICHER LA TUILE ACTUELLE (EN MAIN)
	var titre_actuelle = Label.new()
	titre_actuelle.text = "Plateforme actuelle :"
	file_attente_ui.add_child(titre_actuelle)
	file_attente_ui.add_child(creer_grille_ui(pattern_en_attente))
	
	# 2. AFFICHER LES TUILES SUIVANTES
	var titre_suivantes = Label.new()
	titre_suivantes.text = "Suivantes :"
	titre_suivantes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	file_attente_ui.add_child(titre_suivantes)
	
	for pattern in file_attente_patterns:
		file_attente_ui.add_child(creer_grille_ui(pattern))

# Petite fonction outil pour éviter de répéter le code de dessin
func creer_grille_ui(pattern) -> GridContainer:
	var grille_2d = GridContainer.new()
	grille_2d.columns = 5
	grille_2d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	for z in range(5):
		for x in range(5):
			var rect = ColorRect.new()
			rect.custom_minimum_size = Vector2(12, 12)
			if pattern[z][x] == 0: rect.color = Color(0.2, 0.8, 0.2)
			elif pattern[z][x] > 0: rect.color = Color(0.6, 0.4, 0.2) # <-- CORRECTION ICI
			grille_2d.add_child(rect)
	return grille_2d
		
func ouvrir_menu_action_tour(case: Vector3i):
	case_tour_selectionnee = case
	var tour = tours_sur_grille[case]
	var stats = GameData.tours[tour.id_tour]
	
	texte_action_tour.text = tour.id_tour.capitalize() + " (Niveau " + str(tour.niveau) + ")"
	btn_ameliorer.text = "Améliorer (🪙 " + str(stats["prix_amelioration"]) + ")"
	btn_vendre.text = "Vendre (+🪙 " + str(stats["prix_revente"]) + ")"
	
	menu_tours.hide()
	menu_action_tour.show()

func fermer_menu_action_tour():
	case_tour_selectionnee = Vector3i(999,999,999)
	menu_action_tour.hide()
	menu_tours.show()

func ameliorer_tour_selectionnee():
	var tour = tours_sur_grille[case_tour_selectionnee]
	var prix = GameData.tours[tour.id_tour]["prix_amelioration"]
	
	if or_joueur >= prix:
		or_joueur -= prix
		tour.ameliorer()
		fermer_menu_action_tour()
		mettre_a_jour_ui()
	else:
		print("Pas assez d'or pour améliorer !")

func vendre_tour_selectionnee():
	var tour = tours_sur_grille[case_tour_selectionnee]
	var gain = GameData.tours[tour.id_tour]["prix_revente"]
	
	or_joueur += gain
	tour.queue_free() # On détruit la tour
	tours_sur_grille.erase(case_tour_selectionnee) # On libère la case dans le dico !
	
	fermer_menu_action_tour()
	mettre_a_jour_ui()
	
func obtenir_modele_et_rotation(x: int, z: int, pattern: Array) -> Dictionary:
	# On regarde si on a des voisins qui sont des chemins (ou si on touche le bord de la tuile 5x5)
	var haut = (z == 0) or (pattern[z-1][x] > 0)
	var bas = (z == 4) or (pattern[z+1][x] > 0)
	var gauche = (x == 0) or (pattern[z][x-1] > 0)
	var droite = (x == 4) or (pattern[z][x+1] > 0)
	
	# On crée un "code" unique selon les voisins
	var masque = 0
	if haut: masque += 1
	if bas: masque += 2
	if gauche: masque += 4
	if droite: masque += 8
	
	var id_modele = 3 # Droit par défaut
	var rot = 0     # 0 degrés
	
	match masque:
		# --- LIGNES DROITES (Modèle 3) ---
		1, 2, 3: 
			id_modele = 3; rot = 0 # Vertical (Haut et/ou Bas)
		4, 8, 12: 
			id_modele = 3; rot = 1 # Horizontal (Gauche et/ou Droite)
			
		# --- VIRAGES (Modèle 2) ---
		# /!\ Si tes virages sont tournés du mauvais côté en jeu, échange les chiffres `rot` ici !
		9: 
			id_modele = 2; rot = 3 # Haut + Gauche
		10: 
			id_modele = 2; rot = 0 # Haut + Droite
		6: 
			id_modele = 2; rot = 1 # Bas + Droite
		5: 
			id_modele = 2; rot = 2 # Bas + Gauche
			
		# --- CROISEMENTS EN T (Modèle 4) ---
		# /!\ Idem, si le T pointe du mauvais côté, mélange les `rot`
		14: 
			id_modele = 4; rot = 0 # Gauche + Bas + Droite
		7: 
			id_modele = 4; rot = 1 # Haut + Bas + Gauche
		11: 
			id_modele = 4; rot = 3 # Haut + Bas + Droite
		13: 
			id_modele = 4; rot = 2 # Gauche + Haut + Droite
			
		# --- CROISEMENT CROIX (Modèle 1) ---
		15: 
			id_modele = 1; rot = 0
			
	return {"id": id_modele, "rot": rot}
