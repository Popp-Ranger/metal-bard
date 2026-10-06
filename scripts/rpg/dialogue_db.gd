class_name DialogueDB
extends RefCounted
## Dialogues des PNJ. Chaque dialogue est un dictionnaire :
##   "lines":   [[orateur, texte], ...]
##   "choices": [[libellé, action, garder_ouvert?], ...]
## Actions : "close", "goto:<id>" (enchaîne un autre dialogue), ou toute action
## gérée par GameState.run_dialogue_action (accept:, turn_in:, portal, buy_potion, rest...).

const NPCS := {
	"gerald": {"name": "Gérald Pissenlit", "title": "Fromager du coin", "color": Color(0.85, 0.75, 0.45)},
	"brunhilde": {"name": "Grokk Chope-de-Fer", "title": "Tavernier orc", "color": Color(0.95, 0.55, 0.35)},
	"zarathos": {"name": "Ozz", "title": "Mage des portails", "color": Color(0.7, 0.6, 1.0)},
	"inconnue": {"name": "L'Inconnue encapuchonnée", "title": "???", "color": Color(0.75, 0.3, 0.35)},
	"borin": {"name": "Borin Barbe-de-Bière", "title": "Client (très) détendu", "color": Color(0.9, 0.7, 0.4)},
	"sylvaine": {"name": "Sylvaine Luth-d'Argent", "title": "Barde rivale", "color": Color(0.6, 0.9, 0.85)},
	"katrkar": {"name": "Katrkar", "title": "Aventurier brisé", "color": Color(0.95, 0.65, 0.45)},
	"backjlack": {"name": "Back Jlack", "title": "Le Sage du Rock", "color": Color(1.0, 0.62, 0.25)},
	"minotaure": {"name": "Le Minotaure", "title": "Gardien du Labyrinthe du Destin", "color": Color(1.0, 0.55, 0.35)},
	"client": {"name": "Client", "title": "", "color": Color(0.8, 0.78, 0.72)},
	"tableau": {"name": "Tableau des quêtes", "title": "", "color": Color(0.8, 0.75, 0.6)},
}

## Nom du héros choisi à la création du personnage.
static func hero() -> String:
	return GameState.hero_name


static func npc_name(id: String) -> String:
	var n: String = NPCS.get(id, {}).get("name", id)
	return n


static func npc_color(id: String) -> Color:
	var c: Color = NPCS.get(id, {}).get("color", Color.WHITE)
	return c


static func get_dialogue(id: String) -> Dictionary:
	match id:
		"gerald":
			return _gerald()
		"zarathos":
			return _zarathos()
		"brunhilde":
			return _brunhilde()
		"brunhilde_rumeurs":
			return _brunhilde_rumeurs()
		"inconnue":
			return _inconnue()
		"borin":
			return _borin()
		"sylvaine":
			return _sylvaine()
		"tableau":
			return _tableau()
		"katrkar":
			return _katrkar()
		"gloubah":
			return _gloubah()
		"gloubah_antre":
			return _gloubah_antre()
		"gloubah_mignon":
			return _gloubah_mignon()
		"katrkar_epee":
			return _katrkar_epee()
		"intro_hero":
			return _intro_hero()
		"inconnue_oubli":
			return _inconnue_oubli()
		"backjlack":
			return _backjlack()
		"backjlack_reussite":
			return _backjlack_reussite()
		"backjlack_echec":
			return _backjlack_echec()
		"minotaure_duel":
			return _minotaure_duel()
	if id.begins_with("client|"):
		return _client(id.substr(7))
	return {"lines": [["???", "..."]], "choices": []}


## Narration (apartés du conteur), en italique dans la fenêtre de dialogue.
const NARRATOR := "Narrateur"

## Relances de Gérald quand on refuse sa quête : il revient sans cesse, de plus en plus insistant, jusqu'au
## fromage d'hibours (dernière relance, qui tourne ensuite en boucle).
const GERALD_PLEAS := [
	"Et maintenant, tu veux bien ?",
	"Et maintenant ?",
	"Et là ?",
	"Allééééééééééé...",
	"Je te donnerai du fromage d'hibours !",
]


static func _gerald() -> Dictionary:
	var g := npc_name("gerald")
	match GameState.quest_state("plumeau"):
		QuestDB.State.AVAILABLE:
			var refusals := int(GameState.flags.get("gerald_refus", 0))
			if refusals > 0:
				return _gerald_plea(g, refusals)
			return {
				"lines": [
					[NARRATOR, "Un petit homme aux pieds nus (fort bien épilés) trottine jusqu'à votre table."],
					[NARRATOR, "Ce n'est autre que Gérald Pissenlit, le fromager de la Comt... du coin. Les droits d'auteur ne sont pas dans notre budget."],
					[g, "Par ma meule ! Vous êtes %s ? %s dont la guitare crache la foudre ?" % [GameState.g("le barde", "la barde"), GameState.g("Celui", "Celle")]],
					[g, "C'est Plumeau, mon petit hibours adoré. Des squelettes l'ont enlevé cette nuit, en pleine traite !"],
					[g, "Ils claquaient des dents en rythme et chantaient faux. Ils ont filé vers les Catacombes Suintantes."],
					[g, "Vous seul pouvez le sauver !"],
					[hero(), "Moi seul ?"],
					[g, "Bon... vous et les 3471 autres héros à qui je l'ai demandé ce soir. Mais j'ai toute une ferme d'hibours à traire, je ne peux pas y aller moi-même !"],
					[g, "Alors, vous m'aidez ? Je vous donnerai 50 médiators... et un objet incroyable, dans ma famille depuis très, très longtemps :"],
					[g, "le portrait de mon arrière-arrière-arrière-grand-mère."],
				],
				"choices": [
					["« Aucun os ne résiste à un bon riff. J'y vais. »", "accept:plumeau"],
					["« Non. Je reste ici avec mon thé glacé et mon brie. »", "refuse:plumeau"],
				],
			}
		QuestDB.State.ACTIVE:
			return {
				"lines": [
					[g, "Ozz, le grand mage près du cercle de runes, vous ouvrira un portail vers les catacombes."],
					[g, "Faites vite... Plumeau a peur du noir. Et des squelettes. Et des grenouilles."],
				],
				"choices": [["« J'y cours. »", "close"]],
			}
		QuestDB.State.OBJECTIVE_DONE:
			return {
				"lines": [
					[g, "PLUMEAU ! Mon tout petit ! Tu es sain et sauf !"],
					["Plumeau", "Hou-grrrr ! Hou-hou !"],
					[g, "Un roi grenouille ?! Qui commande à des squelettes ?! ...Non, ne m'expliquez pas. Vous êtes %s." % GameState.g("un héros", "une héroïne")],
					[g, "Comme promis : 50 médiators. Et... (il vous tend un vieux cadre, les mains tremblantes)"],
					[g, "le portrait de mon arrière-arrière-arrière-grand-mère. Elle veillera sur vous. Elle veille sur tout le monde. Tout le temps."],
				],
				"choices": [["Rendre Plumeau à Gérald", "turn_in:plumeau"]],
			}
		QuestDB.State.TURNED_IN:
			return {
				"lines": [
					[g, "Plumeau ne vous quitte plus des yeux. Je crois qu'il veut apprendre la guitare."],
					["Plumeau", "Hou-hou ! (il mime un headbang)"],
					[g, "Revenez quand vous voulez : il y aura toujours du brie pour vous."],
				],
				"choices": [["« Rock on, petit. »", "close"]],
			}
	return {"lines": [[g, "Bonjour, étranger."]], "choices": []}


## Gérald revient à la charge après un refus (`refusals` = nombre de refus, 5 au plus).
static func _gerald_plea(g: String, refusals: int) -> Dictionary:
	var k := clampi(refusals, 1, GERALD_PLEAS.size()) - 1
	var accept := ["« Bon, d'accord. J'y vais. »", "accept:plumeau"]
	if k < GERALD_PLEAS.size() - 1:
		return {
			"lines": [[g, str(GERALD_PLEAS[k])]],
			"choices": [accept, ["« Non. »", "refuse:plumeau"]],
		}
	# Dernière relance : le fromage d'hibours, offert la première fois, puis la même proposition en boucle.
	if not bool(GameState.flags.get("cheese_given", false)):
		return {
			"lines": [
				[g, str(GERALD_PLEAS[k])],
				[NARRATOR, "Il sort de sa poche une part de fromage d'hibours, tiède et légèrement poilue. Ça sent... la ferme."],
				[g, "Revenez me voir si vous changez d'avis."],
			],
			"choices": [
				["« Pour du fromage d'hibours, j'y vais ! » (le manger)", "cheese+accept:plumeau"],
				["« Toujours non. »", "refuse:plumeau"],
			],
		}
	return {
		"lines": [[g, str(GERALD_PLEAS[k])], [NARRATOR, "(Il n'en a plus, mais il y croit.)"]],
		"choices": [accept, ["« Non. »", "refuse:plumeau"]],
	}


static func _zarathos() -> Dictionary:
	var chapter3 := _ozz_labyrinthe()
	if not chapter3.is_empty():
		return chapter3
	var z := npc_name("zarathos")
	var state := GameState.quest_state("plumeau")
	if state == QuestDB.State.ACTIVE:
		if GameState.flags.get("portal_open", false):
			return {
				"lines": [[z, "Le portail est ouvert, il ne tiendra pas éternellement. Enfin si, mais ma patience non."]],
				"choices": [["« J'y vais. »", "close"]],
			}
		return {
			"lines": [
				[z, "Hmm ? Les Catacombes Suintantes ? Un endroit humide, mal éclairé, rempli de squelettes. Charmant."],
				[z, "Elles ont un roi : Gloubah, le Roi Grenouille. Roi de tous les squelettes du donjon."],
				[hero(), "Une grenouille qui règne sur des squelettes ? Pourquoi ?"],
				[z, "Là n'est pas la question. Enfin si, c'est même toute la question. Mais évitons-la."],
				[z, "Sa salle est scellée. Le chef des squelettes en garde la clé : trouve-le, prends-la, et va chercher ta bestiole."],
				[z, "Quand tu l'auras libérée, je t'ouvrirai un portail de retour juste à côté de toi. Comment ? Je suis mage. Je fais des trucs de mage."],
			],
			"choices": [
				["« Ouvre le portail, grand mage. »", "portal"],
				["« Pas encore. »", "close"],
			],
		}
	if state == QuestDB.State.OBJECTIVE_DONE or state == QuestDB.State.TURNED_IN:
		return {
			"lines": [
				[z, "J'ai senti ton solo jusqu'ici. Les murs de la taverne ont tremblé, et Grokk a perdu trois chopes."],
				[z, "Il y a d'autres donjons, d'autres portails... Mais l'univers n'est pas encore prêt. Reviens plus tard. (Prochaines quêtes à venir !)"],
			],
			"choices": [["« À bientôt. »", "close"]],
		}
	return {
		"lines": [
			[z, "Je suis Ozz. J'ouvre des portails. Je ferme aussi les portails, mais c'est moins spectaculaire."],
			[z, "Reviens me voir quand quelqu'un aura besoin de tes... talents bruyants."],
		],
		"choices": [["« Entendu. »", "close"]],
	}


## Chapitre 3 : le « pic » du Destin. Vide tant que la quête n'est pas débloquée (après la partition maudite).
static func _ozz_labyrinthe() -> Dictionary:
	var z := npc_name("zarathos")
	var stage := Expedition.stage_name(Expedition.current_stage())
	match GameState.quest_state("labyrinthe_destin"):
		QuestDB.State.AVAILABLE:
			return {
				"lines": [
					[hero(), "Ozz ! Toi qui sais tout... As-tu déjà entendu parler du Pick du Destin ?"],
					[z, "Le pic du Destin ? Évidemment. Tout le monde connaît le pic du Destin."],
					[z, "Il se trouve dans la montagne du Dest... dans le Labyrinthe du Destin. Pardon. C'est un labyrinthe, en haut d'une montagne."],
					[hero(), "Un pick. Un médiator. Pas un sommet."],
					[z, "...Ah. Eh bien figure-toi que c'est le même endroit. Le trésor de ce labyrinthe, c'est ton médiator."],
					[z, "Et il est gardé par, ni plus ni moins que... LE MINOTAURE."],
					[NARRATOR, "Un coup de tonnerre retentit au loin. Derrière le comptoir, Grokk laisse tomber une chope."],
					[z, "Le chemin est long. D'abord la prairie, au pied de la montagne. Puis les flancs, où rôde un Bigfoot qui déteste la musique."],
					[z, "Ensuite les grottes des gobelins, à l'intérieur de la montagne. Leur chef est un troll des cavernes : il se régénère, alors tape vite et tape fort."],
					[z, "Puis le col au bord des précipices. Et un élémentaire de glace grand comme la taverne."],
					[z, "Et enfin, le Labyrinthe : des élémentaires de glace et de roche à chaque détour. Et au centre... lui."],
					[z, "Je t'ouvre un portail jusqu'au pied de la montagne, et un autre après chaque étape. Comment ? Je suis le grand mage. Je fais des trucs de grand mage."],
				],
				"choices": [
					["« En route pour le Labyrinthe du Destin ! »", "accept:labyrinthe_destin+portal"],
					["« Laisse-moi d'abord finir mon thé glacé. »", "close"],
				],
			}
		QuestDB.State.ACTIVE:
			if GameState.flags.get("portal_open", false):
				return {
					"lines": [[z, "Le portail t'attend : %s. Il ne tiendra pas éternellement. Enfin si, mais ma patience non." % stage]],
					"choices": [["« J'y vais. »", "close"]],
				}
			return {
				"lines": [
					[z, "Tu reprends l'ascension ? Je te renvoie là où tu t'étais arrêté%s : %s." % [GameState.g("", "e"), stage]],
					[z, "Et n'oublie pas : au Minotaure, on ne répond pas avec une épée. On répond avec un solo."],
				],
				"choices": [["« Ouvre le portail, grand mage. »", "portal"], ["« Pas encore. »", "close"]],
			}
		QuestDB.State.OBJECTIVE_DONE:
			return {
				"lines": [
					[z, "Ce bourdonnement... LE PICK DU DESTIN ! Tu as vaincu le Minotaure ?"],
					[hero(), "En duel de guitare."],
					[z, "Évidemment. Avec la partition du Riff Ultime et ce pick, Mèhn-Strïm a du souci à se faire."],
					[z, "Garde-les précieusement. La suite, je la sens venir... et elle sent le soufre."],
				],
				"choices": [["Montrer le Pick du Destin à Ozz (terminer la quête)", "turn_in:labyrinthe_destin"]],
			}
		QuestDB.State.TURNED_IN:
			return {
				"lines": [[z, "Le Pick du Destin et la partition du Riff Ultime... Il ne te manque plus qu'un dragon. (Suite de la légende à venir !)"]],
				"choices": [["« Rock on, grand mage. »", "close"]],
			}
	return {}


## Le Minotaure, à 5 % de ses PV : il impose le duel de guitare.
static func _minotaure_duel() -> Dictionary:
	var m := npc_name("minotaure")
	return {
		"lines": [
			[m, "ASSEZ ! Tu crois me vaincre à coups de manche, petit%s troubadour ?" % GameState.g("", "e")],
			[m, "Dans ce labyrinthe, on règle ça à l'ancienne : UN DUEL DE GUITARE."],
			[m, "Tiens mon solo, note pour note, à 80 % au moins, et le Pick du Destin est à toi. Sinon... je fais de toi un médiator."],
		],
		"choices": [["« Branche-toi, la vache. On va voir qui a le plus gros son. »", "story:duel"]],
	}



static func _brunhilde() -> Dictionary:
	var b := npc_name("brunhilde")
	return {
		"lines": [
			[b, "Bienvenue à la Chèvre Fringante, barde. Ici on paie d'avance et on ne joue pas de ballades elfiques."],
			[b, "Potion de soin à %d médiators, chambre à %d médiators la nuit. Tu as %d médiators." % [
				ItemDB.potion_price(), ItemDB.rest_price(), GameState.gold]],
		],
		"choices": [
			["Acheter une potion de soin (%d médiators)" % ItemDB.potion_price(), "buy_potion", true],
			["Louer une chambre pour se reposer à l'étage (%d médiators)" % ItemDB.rest_price(), "rest", true],
			["Vendre ou racheter de l'équipement", "shop"],
			["« Des rumeurs ? »", "goto:brunhilde_rumeurs"],
			["« À plus tard. »", "close"],
		],
	}


static func _brunhilde_rumeurs() -> Dictionary:
	var b := npc_name("brunhilde")
	return {
		"lines": [
			[b, "Des rumeurs ? Depuis un mois, les morts ne restent plus couchés. Ils volent tout ce qui fait du bruit : cloches, tambours, poulets..."],
			[b, "Les anciens parlent de Morne, la Liche du Silence. Il paraît qu'elle veut faire taire le monde entier."],
			[b, "Moi, tant qu'ils ne volent pas mes fûts, je m'en fiche. Mais un barde comme toi... tu devrais t'en soucier."],
		],
		"choices": [["« Intéressant... »", "goto:brunhilde"]],
	}


static func _inconnue() -> Dictionary:
	var i := npc_name("inconnue")
	var forget := ["« Efface mes talents, je veux réécrire ma partition. »", "goto:inconnue_oubli"]
	match GameState.quest_state("pick_destin"):
		QuestDB.State.AVAILABLE:
			# Chapitre 2 : de retour à la taverne après Plumeau, elle appelle le héros.
			return {
				"lines": [
					[i, "Te voilà enfin, barde. Je t'appelais... Tu n'entendais donc pas ?"],
					[i, "Gloubah n'était qu'un pion. Ce qui vient est bien plus grand qu'une grenouille couronnée."],
					[i, "Approche. Il est temps que tu entendes la légende du sage... la légende de Back Jlack."],
				],
				"choices": [
					["« Je t'écoute. »", "accept:pick_destin+story:legende"],
					["« Plus tard. J'ai un brie qui m'attend. »", "close"],
					forget,
				],
			}
		QuestDB.State.ACTIVE, QuestDB.State.OBJECTIVE_DONE:
			return {
				"lines": [[i, "Back Jlack t'attend, en haut des marches interminables. Veux-tu que je t'y renvoie ?"]],
				"choices": [
					["« Renvoie-moi au temple. »", "story:temple"],
					forget,
					["« Pas maintenant. »", "close"],
				],
			}
		QuestDB.State.TURNED_IN:
			return {
				"lines": [
					[i, "Tu as la partition. Il te manque le pick. La légende n'est pas finie, barde..."],
					[i, "Le Pick du Destin... Ozz, le grand mage, a vu passer bien des légendes. Va lui demander."],
					[i, "Quand le Silence viendra, joue plus fort que lui."],
				],
				"choices": [
					["« Renvoie-moi voir Back Jlack. »", "story:temple"],
					forget,
					["(Elle disparaît dans l'ombre...)", "close"],
				],
			}
	return {
		"lines": [
			[i, "...Ton luth. Il est accordé en ré bémol, n'est-ce pas ? L'accordage des anciens rois-bardes."],
			[i, "Les squelettes ne volent pas au hasard. Quelqu'un leur donne des ordres. Quelqu'un qui déteste la musique."],
		],
		"choices": [
			forget,
			["« Qui es-tu ? »", "close"],
		],
	}


## Cinématique de la légende (chapitre 2) : l'Inconnue raconte, sur le visage de Back Jlack en gros plan.
const LEGEND_LINES := [
	"Cette légende passe de barde en barde depuis des siècles...",
	"Il se raconte qu'un métalleux, guitariste et chanteur, le plus sage d'entre les sages, combattit avec l'aide de Satan un mal bien plus grand que tout ce que tu as affronté...",
	"...le fameux Mèhn-Strïm. Un dragon qui souhaitait éradiquer le métal.",
	"Ce sage, c'était Back Jlack.",
	"Mais plutôt que de te raconter cette légende...",
	"...tu vas la vivre !",
]


## Back Jlack, en haut des marches interminables, devant le Temple du Dragon.
static func _backjlack() -> Dictionary:
	var b := npc_name("backjlack")
	var trial := ["« Envoie la sauce. » (épreuve : jouer le Chant de fer)", "flag:temple_met+story:epreuve"]
	match GameState.quest_state("pick_destin"):
		QuestDB.State.OBJECTIVE_DONE:
			return {
				"lines": [
					[b, "Montre-moi ça... PAR LES CORDES DE SATAN ! La partition du Riff Ultime !"],
					[b, "Écoute-moi bien : elle ne se joue qu'avec le Pick du Destin. Sans lui, la foudre frappe celui qui ose. Crois-moi, j'ai essayé. Deux fois."],
					[b, "Le pick n'était pas dans ce temple... Mais avec cette partition, Mèhn-Strïm a du souci à se faire. Garde-la précieusement."],
					[b, "Repose tes doigts, %s. La suite de la légende s'écrira bientôt." % GameState.g("petit", "petite")],
				],
				"choices": [["« Rock on. » (terminer la quête et rentrer à votre époque)", "turn_in:pick_destin+story:retour_epoque"]],
			}
		QuestDB.State.TURNED_IN:
			return {
				"lines": [[b, "La légende continue, barde. Garde ta partition au chaud... et loin de tout orage."]],
				"choices": [["« Rock on. »", "close"]],
			}
	if bool(GameState.flags.get("temple_trial_ok", false)):
		return {
			"lines": [
				[b, "Le temple t'est ouvert. Trouve le Pick du Destin, s'il est là-dedans... et méfie-toi de ce qui y joue faux."],
				[b, "Si tes mollets de coq crient grâce, le portail en bas des marches te ramène à la taverne de ton époque."],
			],
			"choices": [["« J'y vais. »", "close"]],
		}
	if bool(GameState.flags.get("temple_met", false)):
		return {
			"lines": [[b, "Alors ? Tes doigts sont prêts ? Le Chant de fer, note pour note, 80 % au moins. Le métal n'attend pas."]],
			"choices": [trial, ["« Pas encore. »", "close"]],
		}
	return {
		"lines": [
			[b, "Ah ! Te voilà, %s %s. Je t'attendais. Enfin... j'attendais quelqu'un. Et c'est toi." % [GameState.g("petit", "petite"), hero()]],
			[b, "Je suis Back Jlack. Oui, CE Back Jlack. Pas d'autographes."],
			[b, "Écoute-moi bien : le métal est menacé. Mèhn-Strïm, le dragon, veut l'éradiquer de tous les univers."],
			[b, "La seule solution ? Le battre. Avec des riffs. Des riffs toujours plus hardcore."],
			[b, "Mais avant de te laisser entrer dans ce temple, je dois savoir si tu es à la hauteur."],
			[b, "Parce qu'ici, il ne s'agit pas de battre une grenouille ou des squelettes. Non. Ici, ce sont des démons corrompus... par d'autres démons."],
			[b, "...Oui. C'est un truc démoniaque."],
			[b, "Joue-moi mon solo, le Chant de fer, note pour note, en entier : il me faut au moins 80 % de notes justes."],
		],
		"choices": [trial, ["« Laisse-moi m'échauffer les doigts. »", "flag:temple_met"]],
	}


## Épreuve réussie : la porte du temple s'est ouverte dans le tonnerre.
static func _backjlack_reussite() -> Dictionary:
	var b := npc_name("backjlack")
	var lines: Array = [[b, "PAR LES CORNES DU DIABLE ! Ça, c'était un solo !"]]
	if bool(GameState.flags.get("temple_first_try", false)):
		lines.append([b, "Et du premier coup ! Tiens, prends ma bénédiction : +10 % de dégâts pendant 20 minutes."])
	lines.append_array([
		[b, "Le temple t'a entendu. Maintenant, aide-moi à retrouver le Pick du Destin."],
		[b, "Un médiator, quoi. Mais pas n'importe lequel : celui qui permet de jouer le riff ultime... le seul qui puisse vaincre le dragon."],
		[b, "Et si tes mollets de coq en ressentent le besoin, tu peux toujours retourner à la taverne de ton époque pour te reposer. Le portail est en bas des marches."],
		[b, "Tes doigts auront besoin de nouvelles cornes, dures comme le cuir d'un taureau des enfers, pour jouer des riffs infernaux."],
	])
	return {"lines": lines, "choices": [["« Que le riff soit avec nous. »", "close"]]}


static func _backjlack_echec() -> Dictionary:
	var b := npc_name("backjlack")
	return {
		"lines": [
			[b, "Hmm. Non. Non non non. Ça, c'était un solo de kazoo."],
			[b, "Reviens me voir quand tu seras à la hauteur."],
		],
		"choices": [["« Je reviendrai. »", "close"]],
	}


## Début de partie, au cimetière : une seule réplique, au pluriel s'il y a plusieurs joueurs.
static func _intro_hero() -> Dictionary:
	var several := Net.player_count() > 1
	return {
		"lines": [
			[hero(), "Ah. Les morts se sont encore fait la malle."],
			[hero(), "...On n'a rien vu." if several else "...J'ai rien vu."],
			[hero(), "Bon. Une bière à 12°, comme les gros durs ?"],
			[hero(), "Non... ce soir, ce sera un thé glacé à la goyave."],
			[NARRATOR, "Direction la Chèvre Fringante, la taverne réputée pour le meilleur brie de tous les comtés."],
		],
		"choices": [["(Faire genre de n'avoir rien vu et filer à la Chèvre Fringante)", "close"]],
	}


static func _inconnue_oubli() -> Dictionary:
	var i := npc_name("inconnue")
	var count := GameState.talents.size()
	if count == 0:
		return {
			"lines": [[i, "Ta partition est encore vierge, barde. Il n'y a rien à effacer."]],
			"choices": [["« Plus tard, alors. »", "close"]],
		}
	return {
		"lines": [
			[i, "Oublier ce que tes doigts savent... C'est possible. Je retire les notes, tu gardes le silence qu'elles laissent."],
			[i, "Tes %d talent(s) seront effacés, et tu pourras redistribuer tous tes points." % count],
		],
		"choices": [
			["Réinitialiser l'arbre de talents", "reset_talents"],
			["« Non, je garde mon style. »", "close"],
		],
	}


static func _borin() -> Dictionary:
	var lines := [
		"Hic ! Tu joues du luth ? Moi je joue de la chope. Regarde. *glou glou* Magnifique, non ?",
		"Un jour j'ai frappé un squelette avec ma barbe. Il s'est effondré. De rire, mais quand même.",
		"Les grenouilles, c'est des crapauds qui ont réussi. Retiens bien ça, %s." % GameState.g("gamin", "gamine"),
		"Tu sais pourquoi les squelettes ne se battent jamais entre eux ? Ils n'ont pas les tripes. HAHAHA ! Hic.",
	]
	return {"lines": [[npc_name("borin"), str(lines.pick_random())]], "choices": [["« Santé, Borin. »", "close"]]}


static func _sylvaine() -> Dictionary:
	var s := npc_name("sylvaine")
	return {
		"lines": [
			[s, "Tiens, %s. Tu appelles ça de la musique ? Moi, j'appelle ça un orage dans une casserole." % GameState.g("le hurleur", "la hurleuse")],
			[hero(), "Au moins, mon orage à moi foudroie les morts-vivants."],
			[s, "...Touché. Un jour, on fera un duel de solos. Et je gagnerai."],
		],
		"choices": [["« Quand tu veux. »", "close"]],
	}


static func _tableau() -> Dictionary:
	var lines := []
	for id: String in QuestDB.QUESTS:
		var q := QuestDB.get_quest(id)
		var state := GameState.quest_state(id)
		var status := ""
		match state:
			QuestDB.State.AVAILABLE:
				status = "Disponible — voir %s" % npc_name(str(q.get("giver", "")))
			QuestDB.State.ACTIVE:
				status = "En cours"
			QuestDB.State.OBJECTIVE_DONE:
				status = "À rendre"
			QuestDB.State.TURNED_IN:
				status = "Terminée"
			_:
				status = "Verrouillée"
		lines.append(["Tableau", "« %s » — %s" % [q.get("title", id), status]])
	lines.append(["Tableau", "Une affiche déchirée : « RECHERCHÉE — MORNE, LA LICHE DU SILENCE. Récompense : la paix. »"])
	return {"lines": lines, "choices": [["Fermer", "close"]]}


static func _katrkar() -> Dictionary:
	var k := npc_name("katrkar")
	return {
		"lines": [
			[k, "Tu regardes mon fauteuil ? Vas-y, regarde. Tout le monde le fait."],
			[k, "J'étais sur la montagne Céleste, à chercher l'épée du Roi Liche. On disait qu'elle dormait dans la glace, au sommet."],
			[k, "Un troll des montagnes est sorti de la neige. Grand comme la taverne. Il m'a marché dessus... et il a continué sa route, comme si j'étais un caillou."],
			[k, "Mes jambes sont restées là-haut, en quelque sorte. Mais l'épée, elle, y est toujours."],
		],
		"choices": [
			["« Parle-moi de cette épée. »", "goto:katrkar_epee"],
			["« Je suis désolé%s. »" % GameState.g("", "e"), "close"],
		],
	}


static func _katrkar_epee() -> Dictionary:
	var k := npc_name("katrkar")
	return {
		"lines": [
			[k, "Givrelame, l'épée du Roi Liche. On dit que celui qui la tient commande au froid et au silence."],
			[k, "Si Morne, cette Liche du Silence, met la main dessus... plus une note ne résonnera dans ce monde."],
			[k, "Un jour, quand tu seras assez fort%s, reviens me voir. Je te dessinerai le chemin. (Quête à venir)" % GameState.g("", "e")],
		],
		"choices": [["« Compte sur moi. »", "close"]],
	}


const CLIENT_LINES := [
	"Santé, barde ! Joue-nous quelque chose qui fait trembler les chopes !",
	"La bière de Grokk, c'est la meilleure. Ne lui dis pas que j'ai dit ça, il augmenterait les prix.",
	"On dit que les squelettes volent les cloches des temples. Qui vole une cloche, sérieusement ?",
	"J'ai vu un portail violet s'ouvrir tout seul près du grand mage. J'ai renversé ma soupe.",
	"Ne t'assieds pas à la table près de la cheminée : Borin y a laissé ses bottes.",
	"Tu as essayé les mannequins au sous-sol ? Moi, j'ai perdu contre l'un d'eux.",
	"Il paraît que les chambres de l'étage sont hantées. Enfin, surtout la n°4.",
	"Un orc, un ogre et un troll entrent dans une taverne... ah, tu la connais ?",
	"YEAH ! Enfer et damnation, cette bière arrache !",
	"Bordel, barde, joue-nous un truc qui cogne ! Ça, c'est Metal !",
	"Damnation... j'ai encore perdu ma chope. Ah non, elle est dans ma main. YEAH !",
	"Les squelettes ? Qu'ils viennent, bordel ! J'ai un tabouret et de la rancune.",
]


static func _client(client_name: String) -> Dictionary:
	return {"lines": [[client_name, str(CLIENT_LINES.pick_random())]], "choices": [["« À la tienne. »", "close"]]}


# --- Gloubah (boss) : les réponses n'indiquent jamais si elles mènent au combat. ---

static func _gloubah() -> Dictionary:
	var g := "Gloubah"
	return {
		"lines": [
			[g, "CROOOÂÂÂ ! Qui ose patauger dans MON antre ?"],
			[g, "Moi, Gloubah, Roi Grenouille ! Roi de tous les squelettes de ce donjon !"],
			[NARRATOR, "Pourquoi une grenouille règne-t-elle sur des squelettes ? Là n'est pas la question. Enfin si. Mais on l'évite."],
			[g, "Un%s barde ? Ici ? Avec un instrument aussi... pointu ?" % GameState.g("", "e")],
		],
		"choices": [
			["« Je me rends. »", "story:gloubah_surrender"],
			["« Je vais te ridiculiser dans un combat à mort, grenouille. »", "story:gloubah_fight"],
			["« Que fais-tu donc ici, dans cette antre... luxueuse ? »", "goto:gloubah_antre"],
		],
	}


static func _gloubah_antre() -> Dictionary:
	var g := "Gloubah"
	return {
		"lines": [
			[g, "Luxueuse, n'est-ce pas ? Nénuphars importés, vase millésimée, moustiques de premier choix..."],
			[g, "Mais toi, petit%s barde, que viens-tu faire dans ma mare ?" % GameState.g("", "e")],
		],
		"choices": [
			["« Je viens libérer le hibours que tu as volé. »", "story:gloubah_fight"],
			["« Mais... n'est-il pas trop mignon pour qu'on lui fasse du mal ? »", "goto:gloubah_mignon"],
		],
	}


static func _gloubah_mignon() -> Dictionary:
	var g := "Gloubah"
	return {
		"lines": [
			[g, "Oui... c'est vrai qu'il est mignon. C'est pour lui faire des mamours qu'il est là."],
			["Plumeau", "Hou... (il n'a pas l'air d'apprécier les mamours visqueux)"],
		],
		"choices": [
			["« J'en profite pour attaquer l'abominable grenouille suintante ! »", "story:gloubah_fight"],
			["« Bah oui, il est kiki... Libère-le, qu'il puisse à nouveau gambader dehors avec ses amis. »", "story:gloubah_friend"],
		],
	}
