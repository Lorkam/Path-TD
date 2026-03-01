extends Control

# Remplace "VBoxContainer/BtnJouer" par le vrai chemin/nom de tes nœuds dans l'arbre à gauche !
@onready var btn_jouer = $VBoxContainer/btnJouer
@onready var btn_options = $VBoxContainer/btnOption
@onready var btn_quitter = $VBoxContainer/btnQuitter

func _ready():
	# On connecte les clics des boutons à nos fonctions
	btn_jouer.pressed.connect(lancer_jeu)
	btn_quitter.pressed.connect(quitter_jeu)
	
	# Pour le bouton Options, on le connecte à une fonction vide pour plus tard
	btn_options.pressed.connect(ouvrir_options)

func lancer_jeu():
	# Charge la scène principale du jeu
	get_tree().change_scene_to_file("res://main.tscn")

func ouvrir_options():
	print("Menu options en construction !")

func quitter_jeu():
	# Ferme l'application proprement
	get_tree().quit()
