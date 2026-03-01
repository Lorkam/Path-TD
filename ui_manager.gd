extends CanvasLayer

# --- SIGNAUX --- 
# Ils servent de "téléphone" pour prévenir le main.gd qu'un bouton a été cliqué
signal bouton_jouer_presse
signal bouton_recommencer_presse
signal bouton_quitter_presse
signal tour_selectionnee(id_tour)
signal ameliorer_tour_pressee
signal vendre_tour_pressee
signal annuler_presse
signal lancer_vague_presse
signal pause_pressee
signal vitesse_normale_pressee
signal avance_rapide_pressee

@onready var affichage_stats = $AffichageStats
@onready var menu_tours = $MenuTours
@onready var menu_principal = $MenuPrincipal
@onready var menu_game_over = $MenuGameOver
@onready var menu_victoire = $MenuVictoire
@onready var file_attente_ui = $FileAttenteUI
@onready var menu_action_tour = $MenuActionTour
@onready var texte_action_tour = $MenuActionTour/VBoxContainer/TexteInfo
@onready var btn_ameliorer = $MenuActionTour/VBoxContainer/BtnAmeliorer
@onready var btn_vendre = $MenuActionTour/VBoxContainer/BtnVendre
@onready var controles_temps = $ControlesTemps

func _ready():
	# On relie les clics de nos boutons à l'envoi de nos signaux
	$MenuPrincipal/BoutonJouer.pressed.connect(func(): bouton_jouer_presse.emit())
	$MenuPrincipal/BoutonQuitter.pressed.connect(func(): bouton_quitter_presse.emit())
	$MenuGameOver/BoutonRecommencer.pressed.connect(func(): bouton_recommencer_presse.emit())
	$MenuGameOver/BoutonQuitter.pressed.connect(func(): bouton_quitter_presse.emit())
	$MenuVictoire/BoutonRecommencer.pressed.connect(func(): bouton_recommencer_presse.emit())
	$MenuVictoire/BoutonQuitter.pressed.connect(func(): bouton_quitter_presse.emit())
	$ControlesTemps/BtnLancerVague.pressed.connect(func(): lancer_vague_presse.emit())
	$ControlesTemps/BtnPause.pressed.connect(func(): pause_pressee.emit())
	$ControlesTemps/BtnVitesse1.pressed.connect(func(): vitesse_normale_pressee.emit())
	$ControlesTemps/BtnVitesse2.pressed.connect(func(): avance_rapide_pressee.emit())
	
	$MenuActionTour/VBoxContainer/BtnFermer.pressed.connect(func(): annuler_presse.emit())
	btn_ameliorer.pressed.connect(func(): ameliorer_tour_pressee.emit())
	btn_vendre.pressed.connect(func(): vendre_tour_pressee.emit())
	
	generer_menu_tours()

# ==========================================
# GESTION DE L'AFFICHAGE DES MENUS
# ==========================================

func afficher_menu_principal():
	menu_principal.show()
	menu_game_over.hide()
	menu_victoire.hide()
	affichage_stats.hide()
	menu_tours.hide()
	file_attente_ui.hide()
	menu_action_tour.hide()
	controles_temps.hide()

func afficher_interface_jeu():
	menu_principal.hide()
	affichage_stats.show()
	menu_tours.show()
	file_attente_ui.show()
	controles_temps.show()

func afficher_game_over():
	menu_game_over.show()
	affichage_stats.hide()
	menu_tours.hide()
	file_attente_ui.hide()
	controles_temps.hide()

func afficher_victoire():
	menu_victoire.show()
	affichage_stats.hide()
	menu_tours.hide()
	file_attente_ui.hide()
	controles_temps.hide()

func mettre_a_jour_texte_pause(en_pause: bool):
	if en_pause:
		$ControlesTemps/BtnPause.text = "▶ Reprendre"
	else:
		$ControlesTemps/BtnPause.text = "⏸ Pause"

func mettre_a_jour_stats(or_joueur: int, vies_joueur: int, texte_phase: String):
	affichage_stats.text = "🪙 Or : " + str(or_joueur) + "   ❤️ Vies : " + str(vies_joueur) + texte_phase

# ==========================================
# GESTION DES TOURS ET ACTIONS
# ==========================================

func generer_menu_tours():
	for enfant in menu_tours.get_children(): enfant.queue_free()
	for id_tour in GameData.tours.keys():
		var infos = GameData.tours[id_tour]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(160, 80)
		btn.text = id_tour.capitalize() + "\n🪙 " + str(infos["prix"]) + " Or"
		# Quand on clique, on prévient le main qu'une tour a été sélectionnée
		btn.pressed.connect(func(): tour_selectionnee.emit(id_tour))
		menu_tours.add_child(btn)

func ouvrir_menu_action_tour(nom_tour: String, niveau: int, prix_amelioration: int, prix_revente: int):
	texte_action_tour.text = nom_tour.capitalize() + " (Niveau " + str(niveau) + ")"
	btn_ameliorer.text = "Améliorer (🪙 " + str(prix_amelioration) + ")"
	btn_vendre.text = "Vendre (+🪙 " + str(prix_revente) + ")"
	menu_tours.hide()
	menu_action_tour.show()

func fermer_menu_action_tour():
	menu_action_tour.hide()
	menu_tours.show()

# ==========================================
# GESTION DU DESSIN DE LA FILE D'ATTENTE
# ==========================================

func dessiner_file_attente(tuile_actuelle: Array, tuiles_suivantes: Array):
	for enfant in file_attente_ui.get_children(): enfant.queue_free()
	file_attente_ui.add_theme_constant_override("separation", 15)
	
	var titre_actuelle = Label.new()
	titre_actuelle.text = "Plateforme actuelle :"
	file_attente_ui.add_child(titre_actuelle)
	file_attente_ui.add_child(creer_grille_ui(tuile_actuelle))
	
	var titre_suivantes = Label.new()
	titre_suivantes.text = "Suivantes :"
	titre_suivantes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	file_attente_ui.add_child(titre_suivantes)
	
	for pattern in tuiles_suivantes:
		file_attente_ui.add_child(creer_grille_ui(pattern))

func creer_grille_ui(pattern) -> GridContainer:
	var grille_2d = GridContainer.new()
	grille_2d.columns = 5
	grille_2d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for z in range(5):
		for x in range(5):
			var rect = ColorRect.new()
			rect.custom_minimum_size = Vector2(12, 12)
			if pattern[z][x] == 0: rect.color = Color(0.2, 0.8, 0.2)
			elif pattern[z][x] > 0: rect.color = Color(0.6, 0.4, 0.2)
			grille_2d.add_child(rect)
	return grille_2d
