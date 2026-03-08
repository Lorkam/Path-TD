extends Node3D

@onready var camera = $Camera3D
@onready var grid_map = $GridMap
@onready var preview_grid = $PreviewGridMap
@onready var ui = $CanvasLayer
@onready var wave_manager = $WaveManager

var file_attente_patterns = [] 
var tours_sur_grille = {}      
var indicateur_portee: MeshInstance3D
var case_tour_survolee = Vector3i(999,999,999)
var case_tour_selectionnee = Vector3i(999,999,999)

var ennemi_scene = preload("res://ennemi.tscn")
var tour_scene = preload("res://tour.tscn")
var noyau_scene = preload("res://noyau.tscn")
var marqueur_scene = preload("res://marqueur_emplacement.tscn")

var astar = AStarGrid2D.new()
var sol_imaginaire = Plane(Vector3.UP, 0.5)
var index_rotation = 0
var map_rotations = [0, 22, 10, 16] 

var or_joueur = GameData.or_depart
var vies_joueur = GameData.vies_depart

enum Phase { MENU, PLACEMENT, PREPARATION, COMBAT, FIN }
var phase_actuelle = Phase.MENU

var vitesse_actuelle = 1.0
var jeu_en_pause = false

var pattern_en_attente = []
var case_preview_actuelle = Vector3i(999, 999, 999)

var tour_selectionnee = ""
var fantome_tour: Node3D = null 
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
			
	noeud_marqueurs = Node3D.new()
	add_child(noeud_marqueurs)
	
	# --- 1. CRÉATION DU SOL ET TERRAIN DE BASE ---
	generer_terrain_base()
	generer_tuiles_initiales() # <-- Place les 4 tuiles de départ
	
	ui.bouton_jouer_presse.connect(commencer_jeu)
	ui.bouton_quitter_presse.connect(quitter_jeu)
	ui.bouton_recommencer_presse.connect(recommencer_jeu)
	ui.annuler_presse.connect(fermer_menu_action_tour)
	ui.ameliorer_tour_pressee.connect(ameliorer_tour_selectionnee)
	ui.vendre_tour_pressee.connect(vendre_tour_selectionnee)
	ui.tour_selectionnee.connect(selectionner_tour)
	
	ui.lancer_vague_presse.connect(lancer_vague)
	ui.pause_pressee.connect(basculer_pause)
	ui.vitesse_normale_pressee.connect(mettre_vitesse_normale)
	ui.avance_rapide_pressee.connect(mettre_avance_rapide)
	
	wave_manager.initialiser(self)
	wave_manager.vague_terminee.connect(terminer_vague)
	wave_manager.victoire.connect(declencher_victoire)
	wave_manager.vague_demarree.connect(mettre_a_jour_ui)
	
	file_attente_patterns.clear()
	for i in range(GameData.taille_file_plateformes):
		file_attente_patterns.append(GameData.patterns_plateformes.pick_random())
		
	indicateur_portee = MeshInstance3D.new()
	var cyl_portee = CylinderMesh.new()
	cyl_portee.height = 0.25 
	var mat_portee = StandardMaterial3D.new()
	mat_portee.albedo_color = Color(1.0, 0.8, 0.0, 0.3) 
	mat_portee.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_portee.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
	indicateur_portee.mesh = cyl_portee
	indicateur_portee.set_surface_override_material(0, mat_portee)
	add_child(indicateur_portee)
	indicateur_portee.hide()
	
	piocher_prochaine_plateforme()
	commencer_jeu()

# ==========================================
# GÉNÉRATION DYNAMIQUE DES MODÈLES 3D
# ==========================================

func creer_visuel_entite(infos: Dictionary) -> Node3D:
	var chemin_modele = infos.get("modele", "")
	
	if chemin_modele != "" and ResourceLoader.exists(chemin_modele):
		var scene = load(chemin_modele).instantiate()
		
		# --- 1. CORRECTION DE LA ROTATION ---
		var rot_y = infos.get("rotation_y", 0.0)
		scene.rotation_degrees.y = rot_y
		
		# --- 2. CORRECTION DE LA TAILLE (SCALE) ---
		# On récupère ton champ "scale" (par défaut 1.0 si tu l'as oublié sur un monstre)
		var echelle = infos.get("scale", 1.0)
		# On l'applique sur les 3 axes (X, Y, Z) pour garder les proportions
		scene.scale = Vector3(echelle, echelle, echelle)
		
		# --- 3. CORRECTION DE LA HAUTEUR ---
		var hauteur = infos.get("hauteur_y", 0.2)
		scene.position.y = hauteur
		
		# --- 4. GESTION DE L'ANIMATION ---
		var anim = infos.get("animation", "")
		var lecteurs = scene.find_children("*", "AnimationPlayer", true, false)
		
		for lecteur in lecteurs:
			if lecteur != null and lecteur is AnimationPlayer:
				if anim != "" and lecteur.has_animation(anim):
					var animation_trouvee = lecteur.get_animation(anim)
					if animation_trouvee != null:
						animation_trouvee.loop_mode = Animation.LOOP_LINEAR
						
					lecteur.play(anim)
					break 
					
		return scene
			
	# Sinon, Cube Rouge d'erreur
	var fallback = MeshInstance3D.new()
	var cube = BoxMesh.new()
	cube.size = Vector3(0.5, 0.5, 0.5)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	fallback.mesh = cube
	fallback.set_surface_override_material(0, mat)
	fallback.position = Vector3(0, 0.25, 0)
	return fallback

# ==========================================
# GESTION DU TEMPS ET DES ÉTATS
# ==========================================

func basculer_pause():
	if phase_actuelle == Phase.MENU or phase_actuelle == Phase.FIN: return
	jeu_en_pause = !jeu_en_pause
	if jeu_en_pause: Engine.time_scale = 0.0
	else: Engine.time_scale = vitesse_actuelle
	ui.mettre_a_jour_texte_pause(jeu_en_pause)

func mettre_vitesse_normale():
	vitesse_actuelle = 1.0
	if not jeu_en_pause: Engine.time_scale = vitesse_actuelle

func mettre_avance_rapide():
	vitesse_actuelle = 2.0 
	if not jeu_en_pause: Engine.time_scale = vitesse_actuelle

func commencer_jeu():
	Engine.time_scale = 1.0
	phase_actuelle = Phase.PLACEMENT
	ui.afficher_interface_jeu()
	maj_emplacements_valides()
	mettre_a_jour_ui()
	ui.desactiver_bouton_vague(true)

func declencher_game_over():
	Engine.time_scale = 0
	phase_actuelle = Phase.FIN
	ui.afficher_game_over()

func declencher_victoire():
	Engine.time_scale = 0
	phase_actuelle = Phase.FIN
	ui.afficher_victoire()

func recommencer_jeu():
	Engine.time_scale = 1.0 
	get_tree().reload_current_scene()

func quitter_jeu():
	get_tree().quit()

func selectionner_tour(id: String):
	if phase_actuelle in [Phase.PREPARATION, Phase.COMBAT]:
		tour_selectionnee = id
		
		if fantome_tour: fantome_tour.queue_free() 
		fantome_tour = tour_scene.instantiate()
		fantome_tour.id_tour = id
		
		# --- NOUVEAU : On ajoute le visuel à la volée ! ---
		var infos_tour = GameData.tours[id]
		fantome_tour.add_child(creer_visuel_entite(infos_tour))
		
		fantome_tour.set_process(false) 
		if fantome_tour.has_node("ZoneDetection"):
			fantome_tour.get_node("ZoneDetection").monitoring = false
			
		add_child(fantome_tour)
		fantome_tour.hide()
		mettre_a_jour_ui()

# ==========================================
# INPUT ET PRÉVISUALISATION
# ==========================================

func _unhandled_input(event):
	if phase_actuelle == Phase.MENU or phase_actuelle == Phase.FIN: return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and phase_actuelle == Phase.PLACEMENT:
			pivoter_pattern()
		elif event.keycode == KEY_SPACE:
			basculer_pause()
		elif event.keycode == KEY_F1:
			mettre_vitesse_normale()
		elif event.keycode == KEY_F2:
			mettre_avance_rapide()
			
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if phase_actuelle in [Phase.PREPARATION, Phase.COMBAT]:
			tour_selectionnee = "" 
			if fantome_tour: fantome_tour.hide()
			
			if case_tour_selectionnee != Vector3i(999, 999, 999): 
				fermer_menu_action_tour() 
				
			mettre_a_jour_ui()
		
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos_souris = get_viewport().get_mouse_position()
		var impact = sol_imaginaire.intersects_ray(camera.project_ray_origin(pos_souris), camera.project_ray_normal(pos_souris))
		
		if impact == null: 
			if phase_actuelle in [Phase.PREPARATION, Phase.COMBAT]:
				tour_selectionnee = ""
				if fantome_tour: fantome_tour.hide()
				if case_tour_selectionnee != Vector3i(999, 999, 999): fermer_menu_action_tour()
				mettre_a_jour_ui()
			return
			
		var case_clic = grid_map.local_to_map(impact)
		
		if phase_actuelle == Phase.PLACEMENT:
			if case_preview_actuelle in emplacements_valides:
				placer_zone(case_preview_actuelle)
			return
			
		if phase_actuelle in [Phase.PREPARATION, Phase.COMBAT]:
			if case_clic in tours_sur_grille:
				ouvrir_menu_action_tour(case_clic)
				tour_selectionnee = ""
				if fantome_tour: fantome_tour.hide()
				mettre_a_jour_ui()
				return
			
			if tour_selectionnee != "":
				if grid_map.get_cell_item(case_clic) == 0:
					placer_tour(case_clic, tour_selectionnee)
				else:
					tour_selectionnee = ""
					if fantome_tour: fantome_tour.hide()
					mettre_a_jour_ui()
			
			elif case_tour_selectionnee != Vector3i(999, 999, 999):
				fermer_menu_action_tour()

func _process(delta):
	if phase_actuelle == Phase.MENU or phase_actuelle == Phase.FIN: return
		
	var pos_souris = get_viewport().get_mouse_position()
	var impact = sol_imaginaire.intersects_ray(camera.project_ray_origin(pos_souris), camera.project_ray_normal(pos_souris))
	if impact == null: return
	var case_survolee = grid_map.local_to_map(impact)
	
	if case_survolee != case_tour_survolee:
		if case_tour_survolee in tours_sur_grille: tours_sur_grille[case_tour_survolee].set_surbrillance(false)
		if case_survolee in tours_sur_grille: tours_sur_grille[case_survolee].set_surbrillance(true)
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
			
	elif phase_actuelle in [Phase.PREPARATION, Phase.COMBAT] and tour_selectionnee != "":
		if grid_map.get_cell_item(case_survolee) == 0 and fantome_tour:
			fantome_tour.show()
			var pos_locale = grid_map.map_to_local(case_survolee)
			fantome_tour.global_position = Vector3(pos_locale.x, 0.5, pos_locale.z)
		else:
			if fantome_tour: fantome_tour.hide()

	if case_tour_selectionnee != Vector3i(999, 999, 999):
		var tour = tours_sur_grille[case_tour_selectionnee]
		# On lit la portée du niveau actuel
		var portee = GameData.tours[tour.id_tour]["portee"][tour.niveau - 1] 
		indicateur_portee.scale = Vector3(portee * 2, 1, portee * 2) 
		indicateur_portee.global_position = Vector3(tour.global_position.x, 0.55, tour.global_position.z)
		indicateur_portee.show()
		
	elif phase_actuelle in [Phase.PREPARATION, Phase.COMBAT] and tour_selectionnee != "":
		if grid_map.get_cell_item(case_survolee) == 0:
			# On lit la portée du niveau 1 car on est en train d'acheter
			var portee = GameData.tours[tour_selectionnee]["portee"][0] 
			indicateur_portee.scale = Vector3(portee * 2, 1, portee * 2)
			var pos_locale = grid_map.map_to_local(case_survolee)
			indicateur_portee.global_position = Vector3(pos_locale.x, 0.55, pos_locale.z)
			indicateur_portee.show()
		else:
			indicateur_portee.hide() 
			
	else:
		indicateur_portee.hide()

# ==========================================
# MÉCANIQUES (Grille, Tours, Vagues)
# ==========================================

func maj_emplacements_valides():
	for enfant in noeud_marqueurs.get_children(): enfant.queue_free()
	emplacements_valides.clear()
	if phase_actuelle != Phase.PLACEMENT: return
	
	var centres_a_tester = []
	for case in grid_map.get_used_cells():
		if grid_map.get_cell_item(case) > 0: 
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
							var ancien_est_chemin = (type_ancien > 0)
							var nouveau_est_chemin = (type_nouveau > 0)
							if nouveau_est_chemin != ancien_est_chemin: return false
							if nouveau_est_chemin and ancien_est_chemin: connecte_chemin = true
	return connecte_chemin

func pivoter_pattern():
	var nouveau_pattern = []
	for i in range(5):
		var ligne = []
		for j in range(5): ligne.append(pattern_en_attente[4 - j][i])
		nouveau_pattern.append(ligne)
	pattern_en_attente = nouveau_pattern
	index_rotation = (index_rotation + 1) % 4 
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
	ui.desactiver_bouton_vague(false)
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
		tour.id_tour = id_tour 
		
		# --- NOUVEAU : On ajoute le visuel à la volée ! ---
		var infos_tour = GameData.tours[id_tour]
		tour.add_child(creer_visuel_entite(infos_tour))
		
		add_child(tour)
		var c = grid_map.map_to_local(case)
		tour.global_position = Vector3(c.x, 0.5, c.z)
		
		tours_sur_grille[case] = tour 
		or_joueur -= prix
		
		selectionner_tour(tour_selectionnee) 
		mettre_a_jour_ui()

func lancer_vague():
	if phase_actuelle != Phase.PREPARATION: 
		print("Action refusée : Placez d'abord la plateforme.")
		return 
		
	var bouts = trouver_bouts_ouverts()
	if bouts.is_empty(): return
	
	phase_actuelle = Phase.COMBAT
	wave_manager.lancer_vague(bouts)
	mettre_a_jour_ui()
	ui.desactiver_bouton_vague(true)

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

func creer_ennemi(case_depart: Vector3i, type_ennemi: String):
	var depart_2d = Vector2i(case_depart.x, case_depart.z)
	
	for case in grid_map.get_used_cells():
		if grid_map.get_cell_item(case) > 0:
			astar.set_point_weight_scale(Vector2i(case.x, case.z), randf_range(1.0, 1.1))
	
	var chemin_2d = astar.get_id_path(depart_2d, Vector2i(0, 0))
	if chemin_2d.is_empty(): return
		
	var nouvel_ennemi = ennemi_scene.instantiate()
	nouvel_ennemi.type_ennemi = type_ennemi
	
	# --- NOUVEAU : On ajoute le visuel à la volée ! ---
	var infos_ennemi = GameData.ennemis[type_ennemi]
	nouvel_ennemi.add_child(creer_visuel_entite(infos_ennemi))
	
	add_child(nouvel_ennemi)
	
	var centre_3d = grid_map.map_to_local(case_depart)
	nouvel_ennemi.global_position = Vector3(centre_3d.x, 0.5, centre_3d.z)
	
	var chemin_3d: Array[Vector3] = []
	for point in chemin_2d:
		var pos_3d = grid_map.map_to_local(Vector3i(point.x, 0, point.y))
		chemin_3d.append(Vector3(pos_3d.x, 0.5, pos_3d.z))
		
	nouvel_ennemi.chemin = chemin_3d
	nouvel_ennemi.tree_exited.connect(_on_ennemi_mort)

func _on_ennemi_mort():
	wave_manager.signaler_mort_ennemi() 

func terminer_vague():
	phase_actuelle = Phase.PLACEMENT
	maj_emplacements_valides() 
	mettre_a_jour_ui()

func generer_terrain_base():
	# CRÉATION DU SOL GÉANT
	var sol_visuel = MeshInstance3D.new()
	var plane_mesh = BoxMesh.new()
	plane_mesh.size = Vector3(200, 0.1, 200) # Très grand pour couvrir la vue
	var mat_sol = StandardMaterial3D.new()
	mat_sol.albedo_color = Color(0.15, 0.25, 0.1) # Vert foncé naturel
	sol_visuel.mesh = plane_mesh
	sol_visuel.set_surface_override_material(0, mat_sol)
	sol_visuel.global_position = Vector3(0, -0.05, 0) # Juste sous la grille
	add_child(sol_visuel)
	
	# Génération classique de la grille centrale
	for x in range(-2, 3):
		for z in range(-2, 3):
			var absolue = Vector3i(x, 0, z)
			var type_bloc = GameData.pattern_base[z + 2][x + 2]
			
			if type_bloc == 0:
				grid_map.set_cell_item(absolue, 0, 0) 
				astar.set_point_solid(Vector2i(absolue.x, absolue.z), true)
			else:
				var infos = obtenir_modele_et_rotation(x + 2, z + 2, GameData.pattern_base)
				grid_map.set_cell_item(absolue, infos["id"], map_rotations[infos["rot"]])
				astar.set_point_solid(Vector2i(absolue.x, absolue.z), false)
				
	# Création et injection du Noyau dynamique 
	var noyau = noyau_scene.instantiate()
	
	# On crée le visuel avec notre super fonction
	var visuel_noyau = creer_visuel_entite(GameData.noyau)
	
	# On applique le petit ajustement de hauteur si besoin
	visuel_noyau.position.y += GameData.noyau.get("hauteur_y", 0.0)
	
	noyau.add_child(visuel_noyau)
	add_child(noyau)
	
	# Position centrale de la carte
	noyau.global_position = Vector3(0.5, 0.5, 0.5)

# --- NOUVEAU : PLACEMENT AUTOMATIQUE DES 4 TUILES DE DÉPART ---
func generer_tuiles_initiales():
	var directions = [Vector3i(5, 0, 0), Vector3i(-5, 0, 0), Vector3i(0, 0, 5), Vector3i(0, 0, -5)]
	var patterns_possibles = GameData.patterns_plateformes.duplicate()
	
	for centre in directions:
		patterns_possibles.shuffle()
		var place = false
		
		for base_pattern in patterns_possibles:
			if place: break
			var current_pattern = base_pattern.duplicate(true)
			
			for rot in range(4):
				pattern_en_attente = current_pattern
				index_rotation = rot
				
				if est_placement_valide(centre):
					# Placer les blocs manuellement sans déclencher toute l'UI
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
					place = true
					break
				
				# Rotation manuelle pour tester le prochain angle
				var nouveau_pattern = []
				for i in range(5):
					var ligne = []
					for j in range(5): ligne.append(current_pattern[4 - j][i])
					nouveau_pattern.append(ligne)
				current_pattern = nouveau_pattern
	
	# Nettoyage de fin
	pattern_en_attente = []
	index_rotation = 0


# ==========================================
# LIENS VERS L'UI (Signaux et Appels)
# ==========================================

func gagner_or(montant):
	or_joueur += montant; mettre_a_jour_ui()

func perdre_vie():
	vies_joueur -= 1; mettre_a_jour_ui()
	if vies_joueur <= 0: declencher_game_over()

func mettre_a_jour_ui():
	var texte_phase = ""
	if phase_actuelle == Phase.PLACEMENT: 
		texte_phase = " | 🛠️ Place ta plateforme"
	elif phase_actuelle == Phase.PREPARATION: 
		if tour_selectionnee == "": texte_phase = " | 🛡️ Place tes tours et clique sur Lancer !"
		else: texte_phase = " | 🎯 Pose la tour " + tour_selectionnee.capitalize() + " (Clic Droit = Annuler)"
	elif phase_actuelle == Phase.COMBAT: 
		if tour_selectionnee == "": texte_phase = " | ⚔️ VAGUE " + str(wave_manager.numero_vague) + " EN COURS"
		else: texte_phase = " | 🎯 Pose la tour " + tour_selectionnee.capitalize() + " (Clic Droit = Annuler)"
	
	ui.mettre_a_jour_stats(or_joueur, vies_joueur, texte_phase)

func piocher_prochaine_plateforme():
	pattern_en_attente = file_attente_patterns.pop_front()
	file_attente_patterns.append(GameData.patterns_plateformes.pick_random())
	index_rotation = 0 
	ui.dessiner_file_attente(pattern_en_attente, file_attente_patterns)

func ouvrir_menu_action_tour(case: Vector3i):
	case_tour_selectionnee = case
	var tour = tours_sur_grille[case]
	var stats = GameData.tours[tour.id_tour]
	
	# On lit les prix du niveau actuel (index niveau - 1)
	var prix_am = stats["prix_amelioration"][tour.niveau - 1]
	var prix_rev = stats["prix_revente"][tour.niveau - 1]
	
	ui.ouvrir_menu_action_tour(tour.id_tour, tour.niveau, prix_am, prix_rev)

func fermer_menu_action_tour():
	case_tour_selectionnee = Vector3i(999,999,999)
	ui.fermer_menu_action_tour()

func ameliorer_tour_selectionnee():
	var tour = tours_sur_grille[case_tour_selectionnee]
	
	if tour.niveau >= 3: 
		return # Sécurité : la tour est déjà au max
		
	var prix = GameData.tours[tour.id_tour]["prix_amelioration"][tour.niveau - 1]
	
	if or_joueur >= prix:
		or_joueur -= prix
		tour.ameliorer()
		fermer_menu_action_tour()
		mettre_a_jour_ui()

func vendre_tour_selectionnee():
	var tour = tours_sur_grille[case_tour_selectionnee]
	var gain = GameData.tours[tour.id_tour]["prix_revente"][tour.niveau - 1]
	
	or_joueur += gain
	tour.queue_free()
	tours_sur_grille.erase(case_tour_selectionnee) 
	
	fermer_menu_action_tour()
	mettre_a_jour_ui()

func obtenir_modele_et_rotation(x: int, z: int, pattern: Array) -> Dictionary:
	var haut = (z == 0) or (pattern[z-1][x] > 0)
	var bas = (z == 4) or (pattern[z+1][x] > 0)
	var gauche = (x == 0) or (pattern[z][x-1] > 0)
	var droite = (x == 4) or (pattern[z][x+1] > 0)
	
	var masque = 0
	if haut: masque += 1
	if bas: masque += 2
	if gauche: masque += 4
	if droite: masque += 8
	
	var id_modele = 3 
	var rot = 0     
	
	match masque:
		1, 2, 3: id_modele = 3; rot = 0
		4, 8, 12: id_modele = 3; rot = 1
		9: id_modele = 2; rot = 3 
		10: id_modele = 2; rot = 0 
		6: id_modele = 2; rot = 1 
		5: id_modele = 2; rot = 2 
		14: id_modele = 4; rot = 0 
		7: id_modele = 4; rot = 1 
		11: id_modele = 4; rot = 3 
		13: id_modele = 4; rot = 2 
		15: id_modele = 1; rot = 0
			
	return {"id": id_modele, "rot": rot}
