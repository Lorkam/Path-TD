extends Node

# --- PARAMÈTRES DU TERRAIN ---
var taille_plateforme = 5
var taille_file_plateformes = 2 # Nombre de plateformes visibles d'avance en plus de l'actuelle

# --- VARIABLES CAMÉRA ---
var camera = {
	"vitesse_camera" : 30.0,
	"vitesse_zoom" : 2.0,
	"hauteur_max" : 40.0, # zoom minimum
	"hauteur_min" : 6.0, # zoom maximun
}

# 0 = Terrain (Tours), 1 = chemin (Ennemis)
var patterns_plateformes = [
	# Pattern 1 : Ligne droite
	[
		[0, 0, 1, 0, 0],
		[0, 0, 1, 0, 0],
		[0, 0, 1, 0, 0],
		[0, 0, 1, 0, 0],
		[0, 0, 1, 0, 0]
	],
	# Pattern 2 : Virage en L
	[
		[0, 0, 1, 0, 0],
		[0, 0, 1, 0, 0],
		[0, 0, 1, 1, 1],
		[0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0]
	],
	# Pattern 1 : Carrefour en T
	[
		[0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0],
		[1, 1, 1, 1, 1],
		[0, 0, 1, 0, 0],
		[0, 0, 1, 0, 0]
	],
	# Pattern 4 : Carrefour en croix
	[
		[0, 0, 1, 0, 0],
		[0, 0, 1, 0, 0],
		[1, 1, 1, 1, 1],
		[0, 0, 1, 0, 0],
		[0, 0, 1, 0, 0]
	]
]

# Un pattern spécial pour la base centrale (Le Noyau) en forme de croix
var pattern_base = [
	[0, 0, 1, 0, 0],
	[0, 0, 1, 0, 0],
	[1, 1, 1, 1, 1],
	[0, 0, 1, 0, 0],
	[0, 0, 1, 0, 0]
]

# --- PARAMÈTRES DU JOUEUR ---
var or_depart = 50
var vies_depart = 10

# --- STATISTIQUES DES TOURS ---
var tours = {
	"basique": {
		"prix": 20,
		"prix_amelioration": 30,
		"prix_revente": 10,
		"degats": 1,
		"portee": 3.5,
		"cadence_tir": 1.0
	},
	"test": {
		"prix": 40,
		"prix_amelioration": 60,
		"prix_revente": 30,
		"degats": 2,
		"portee": 5,
		"cadence_tir": 0.75
	}
}

# --- STATISTIQUES DES ENNEMIS ---
var ennemis = {
	"standard": {
		"pv": 3,
		"vitesse": 3.0,
		"recompense": 10
	}
	# Tu pourras ajouter "boss", "rapide", etc. ici plus tard !
}

# --- CONFIGURATION DES VAGUES ---
var vagues = [
	[
		{"type": "standard", "nombre_ennemis": 3, "intervalle": 1.5}
	],
	[
		{"type": "standard", "nombre_ennemis": 5, "intervalle": 1.2}
	],
	[
		{"type": "standard", "nombre_ennemis": 10, "intervalle": 0.7}
	],
	[
		{"type": "standard", "nombre_ennemis": 15, "intervalle": 0.6}
	],
	[
		{"type": "standard", "nombre_ennemis": 20, "intervalle": 0.5}
	],
	[
		{"type": "standard", "nombre_ennemis": 30, "intervalle": 0.4}
	]
]
