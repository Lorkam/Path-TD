extends Node

# --- PARAMÈTRES DU TERRAIN ---
var taille_plateforme = 5
var taille_file_plateformes = 2 

# --- VARIABLES CAMÉRA ---
var camera = {
	"vitesse_camera" : 20.0,
	"vitesse_zoom" : 2.0,
	"hauteur_max" : 40.0, 
	"hauteur_min" : 6.0, 
}

var patterns_plateformes = [
	[ [0, 0, 1, 0, 0], [0, 0, 1, 0, 0], [0, 0, 1, 0, 0], [0, 0, 1, 0, 0], [0, 0, 1, 0, 0] ],
	[ [0, 0, 1, 0, 0], [0, 0, 1, 0, 0], [0, 0, 1, 1, 1], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0] ],
	[ [0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [1, 1, 1, 1, 1], [0, 0, 1, 0, 0], [0, 0, 1, 0, 0] ],
	[ [0, 0, 1, 0, 0], [0, 0, 1, 0, 0], [1, 1, 1, 1, 1], [0, 0, 1, 0, 0], [0, 0, 1, 0, 0] ]
]

var pattern_base = [
	[0, 0, 1, 0, 0],
	[0, 0, 1, 0, 0],
	[1, 1, 1, 1, 1],
	[0, 0, 1, 0, 0],
	[0, 0, 1, 0, 0]
]

var or_depart = 120
var vies_depart = 10

var volumeGlobalTirTours = -10

# --- STATISTIQUES DU NOYAU (BASE) ---
var noyau = {
	"pv": 10, 
	"modele": "res://Modeles3D/noyau.gltf",
	"animation": "", 
	"rotation_y": 0,
	"scale": 0.75,
	"hauteur_y": 0.13
}

# --- STATISTIQUES DES TOURS ---
var tours = {
	"baliste": {
		"prix": 60, # Prix de construction (Niveau 1)
		"modele": "res://Modeles3D/weapon-ballista.glb",
		"rotation_y": 180,
		"scale" : 1.0,
		"hauteur_y": 0.13,
		"sonTir" : "res://sons/tirFleche.mp3",
		"volume_tir": 0.0, # 0=son de base, nombres négatif=baisee, positif=augmentation
		
		# --- STATS PAR NIVEAU : [Niv 1, Niv 2, Niv 3] ---
		"prix_amelioration": [80, 200, 0], # 0 = Niveau Max
		"prix_revente": [30, 70, 150],
		"degats": [2, 4, 10], 
		"portee": [4.5, 4.75, 5.0], 
		"cadence_tir": [0.4, 0.3, 0.2],
		"rayon_explosion": [0.0, 0.0, 0.0]
	},
	"canon": {
		"prix": 120,
		"modele": "res://Modeles3D/weapon-cannon.glb",
		"rotation_y": 180,
		"scale" : 1.0,
		"hauteur_y": 0.13,
		"sonTir" : "res://sons/tirFleche.mp3",
		"volume_tir": 0.0,
		
		# --- STATS PAR NIVEAU : [Niv 1, Niv 2, Niv 3] ---
		"prix_amelioration": [150, 400, 0], # 0 = Niveau Max
		"prix_revente": [60, 130, 300],
		"degats": [5, 8, 15],
		"portee": [7.0, 7.5, 8.0], 
		"cadence_tir": [1.5, 1.4, 1.3],
		"rayon_explosion": [2.0, 2.5, 3.0]
	},
}

# --- STATISTIQUES DES ENNEMIS ---
var ennemis = {
	"yeti": {
		"pv": 6,              
		"vitesse": 2.5,       
		"recompense": 4,      
		"modele": "res://Modeles3D/Yeti.gltf",
		"animation": "Run",
		"rotation_y": 180,
		"scale" : 0.3,
		"hauteur_y": 0.1,
	},
}

# --- VAGUES (Mode Horde) ---
var vagues = [
	[ {"type": "yeti", "nombre_ennemis": 10, "intervalle": 1.2} ],  
	[ {"type": "yeti", "nombre_ennemis": 18, "intervalle": 1.0} ],  
	[ {"type": "yeti", "nombre_ennemis": 30, "intervalle": 0.8} ],  
	[ {"type": "yeti", "nombre_ennemis": 50, "intervalle": 0.6} ],  
	[ {"type": "yeti", "nombre_ennemis": 75, "intervalle": 0.4} ],  
	[ {"type": "yeti", "nombre_ennemis": 100, "intervalle": 0.25} ],
	[ {"type": "yeti", "nombre_ennemis": 150, "intervalle": 0.15} ] 
]
