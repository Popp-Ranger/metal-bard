class_name DialogueDB
extends RefCounted
## Dialogues des PNJ. Chaque dialogue est un dictionnaire :
##   "lines":   [[orateur, texte], ...]
##   "choices": [[libellé, action, garder_ouvert?], ...]
## Actions : "close", "goto:<id>" (enchaîne un autre dialogue), ou toute action
## gérée par GameState.run_dialogue_action (accept:, turn_in:, portal, buy_potion, rest...).

const NPCS := {
	"gerald": {"name": "Gérald Pissenlit", "title": "Fermier éploré", "color": Color(0.85, 0.75, 0.45)},
	"brunhilde": {"name": "Brunhilde Chope-de-Fer", "title": "Tavernière ogresse", "color": Color(0.95, 0.55, 0.35)},
	"zarathos": {"name": "Zarathos le Grisonnant", "title": "Mage des portails", "color": Color(0.7, 0.6, 1.0)},
	"inconnue": {"name": "L'Inconnue encapuchonnée", "title": "???", "color": Color(0.75, 0.3, 0.35)},
	"borin": {"name": "Borin Barbe-de-Bière", "title": "Client (très) détendu", "color": Color(0.9, 0.7, 0.4)},
	"sylvaine": {"name": "Sylvaine Luth-d'Argent", "title": "Barde rivale", "color": Color(0.6, 0.9, 0.85)},
	"katrkar": {"name": "Katrkar", "title": "Aventurier brisé", "color": Color(0.95, 0.65, 0.45)},
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
	if id.begins_with("client|"):
		return _client(id.substr(7))
	return {"lines": [["???", "..."]], "choices": []}


static func _gerald() -> Dictionary:
	var g := npc_name("gerald")
	match GameState.quest_state("plumeau"):
		QuestDB.State.AVAILABLE:
			return {
				"lines": [
					[g, "Par les Neuf Enfers... Vous êtes %s ? %s dont la guitare crache la foudre ?" % [GameState.g("le barde", "la barde"), GameState.g("Celui", "Celle")]],
					[g, "C'est Plumeau, mon petit ours-hibou. Une bande de squelettes l'a enlevé cette nuit, en plein poulailler !"],
					[g, "Ils claquaient des dents en rythme et chantaient faux. Je les ai vus filer vers les Catacombes Suintantes."],
					[hero(), "Des squelettes qui chantent faux ? Ça, c'est une offense personnelle."],
					[g, "Je n'ai que 100 médiators et le pendentif de sa mère... mais ramenez-le-moi, je vous en supplie !"],
				],
				"choices": [
					["« Aucun os ne résiste à un bon riff. J'y vais. »", "accept:plumeau"],
					["« Laisse-moi finir ma bière d'abord. »", "close"],
				],
			}
		QuestDB.State.ACTIVE:
			return {
				"lines": [
					[g, "Zarathos, le vieux mage près du cercle de runes, peut vous ouvrir un portail vers les catacombes."],
					[g, "Faites vite... Plumeau a peur du noir. Et des squelettes. Et des grenouilles."],
				],
				"choices": [["« J'y cours. »", "close"]],
			}
		QuestDB.State.OBJECTIVE_DONE:
			return {
				"lines": [
					[g, "PLUMEAU ! Mon tout petit ! Tu es sain et sauf !"],
					["Plumeau", "Hou-grrrr ! Hou-hou !"],
					[g, "Une grenouille géante ? Couronnée ?! Barde, vous êtes %s. Voici tout ce que je possède." % GameState.g("un héros", "une héroïne")],
				],
				"choices": [["Rendre Plumeau à Gérald", "turn_in:plumeau"]],
			}
		QuestDB.State.TURNED_IN:
			return {
				"lines": [
					[g, "Plumeau ne vous quitte plus des yeux. Je crois qu'il veut apprendre la guitare."],
					["Plumeau", "Hou-hou ! (il mime un headbang)"],
				],
				"choices": [["« Rock on, petit. »", "close"]],
			}
	return {"lines": [[g, "Bonjour, étranger."]], "choices": []}


static func _zarathos() -> Dictionary:
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
				[z, "On dit qu'une grenouille gigantesque y règne. Gloubah, reine des Marées Mortes. Elle adore collectionner les bestioles."],
				[z, "Je peux t'y envoyer. Et quand tu auras terminé, je sentirai ta foudre et je t'ouvrirai un chemin de retour."],
			],
			"choices": [
				["« Ouvre le portail, vieil homme. »", "portal"],
				["« Pas encore. »", "close"],
			],
		}
	if state == QuestDB.State.OBJECTIVE_DONE or state == QuestDB.State.TURNED_IN:
		return {
			"lines": [
				[z, "J'ai senti ton solo jusqu'ici. Les murs de la taverne ont tremblé, et Brunhilde a perdu trois chopes."],
				[z, "Il y a d'autres donjons, d'autres portails... Mais l'univers n'est pas encore prêt. Reviens plus tard. (Prochaines quêtes à venir !)"],
			],
			"choices": [["« À bientôt. »", "close"]],
		}
	return {
		"lines": [
			[z, "Je suis Zarathos. J'ouvre des portails. Je ferme aussi les portails, mais c'est moins spectaculaire."],
			[z, "Reviens me voir quand quelqu'un aura besoin de tes... talents bruyants."],
		],
		"choices": [["« Entendu. »", "close"]],
	}


static func _brunhilde() -> Dictionary:
	var b := npc_name("brunhilde")
	return {
		"lines": [
			[b, "Bienvenue au Crâne Hurlant, barde. Ici on paie d'avance et on ne joue pas de ballades elfiques."],
			[b, "Potion de soin à %d médiators, chambre à %d médiators la nuit. Tu as %d médiators." % [
				ItemDB.potion_price(), ItemDB.rest_price(), GameState.gold]],
		],
		"choices": [
			["Acheter une potion de soin (%d médiators)" % ItemDB.potion_price(), "buy_potion", true],
			["Louer une chambre et se reposer (%d médiators)" % ItemDB.rest_price(), "rest", true],
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
	if GameState.quest_state("plumeau") == QuestDB.State.TURNED_IN:
		return {
			"lines": [
				[i, "Tu as vaincu Gloubah. Elle n'était qu'une servante. Sa couronne portait le sceau de Morne."],
				[i, "Quand le Silence viendra, barde, joue plus fort que lui. Nous nous reverrons."],
			],
			"choices": [
				["« Efface mes talents, je veux réécrire ma partition. »", "goto:inconnue_oubli"],
				["(Elle disparaît dans l'ombre...)", "close"],
			],
		}
	return {
		"lines": [
			[i, "...Ton luth. Il est accordé en ré bémol, n'est-ce pas ? L'accordage des anciens rois-bardes."],
			[i, "Les squelettes ne volent pas au hasard. Quelqu'un leur donne des ordres. Quelqu'un qui déteste la musique."],
		],
		"choices": [
			["« Efface mes talents, je veux réécrire ma partition. »", "goto:inconnue_oubli"],
			["« Qui es-tu ? »", "close"],
		],
	}


## Début de partie, au cimetière : une seule réplique, au pluriel s'il y a plusieurs joueurs.
static func _intro_hero() -> Dictionary:
	var several := Net.player_count() > 1
	return {
		"lines": [
			[hero(), "Aaaaaah... une bonne vieille balade par ce temps est si agréable."],
			[hero(), "Et si nous allions nous en jeter un !" if several else "Et si j'allais m'en jeter un !"],
		],
		"choices": [["(Prendre la route du Crâne Hurlant)", "close"]],
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
	"La bière de Brunhilde, c'est la meilleure. Ne lui dis pas que j'ai dit ça, elle augmenterait les prix.",
	"On dit que les squelettes volent les cloches des temples. Qui vole une cloche, sérieusement ?",
	"J'ai vu un portail violet s'ouvrir tout seul près du vieux mage. J'ai renversé ma soupe.",
	"Ne t'assieds pas à la table près de la cheminée : Borin y a laissé ses bottes.",
	"Tu as essayé les mannequins au sous-sol ? Moi, j'ai perdu contre l'un d'eux.",
	"Il paraît que les chambres de l'étage sont hantées. Enfin, surtout la n°4.",
	"Un ogre, une tavernière et un troll entrent dans une taverne... ah, tu la connais ?",
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
			["« Je viens libérer l'ours-hibou que tu as volé. »", "story:gloubah_fight"],
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
