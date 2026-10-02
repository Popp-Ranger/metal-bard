# Animations — récupération sur Mixamo

Objectif : remplacer les animations procédurales de Riffald par de vraies animations
(capture de mouvement Mixamo pour les déplacements et réactions, retouches Blender pour
les gestes signatures du barde), jouées par un AnimationTree dans Godot. L'IK de Godot
garde les mains sur la guitare ; la cape et les cheveux seront animés par des SpringBones.

## Réglages de téléchargement (pour chaque animation)

- Personnage : celui par défaut de Mixamo (Y Bot), inutile d'envoyer Riffald.
- Format : **FBX Binary (.fbx)**
- Skin : **Without Skin** (sauf le fichier de référence ci-dessous)
- Frames per Second : **30**
- Keyframe Reduction : **none**
- Case **In Place** cochée quand elle existe (déplacements).
- Garder le nom de fichier proposé par Mixamo.

Déposer les fichiers dans `assets/animations/mixamo/`.
Ce dossier est ignoré par Godot (`.gdignore`) et par git : les fichiers bruts ne sont
pas redistribués, ils sont convertis dans Blender puis intégrés à `riffald.glb`.

## Fichier de référence (1 seul, avec personnage)

| Recherche | Réglage particulier |
|---|---|
| `T-Pose` | Skin : **With Skin** |

## Indispensables

| Action dans le jeu | Recherche Mixamo | Remarque |
|---|---|---|
| Repos | `Breathing Idle` | |
| Repos (variante) | `Happy Idle` | |
| Marche | `Walking` | In Place |
| Course | `Running` | In Place |
| Coup de guitare (clic) | `Great Sword Slash` | la guitare est tenue comme une hache à deux mains |
| Coup de guitare (variante) | `Great Sword High Spin Attack` | |
| Riff / Accordage | `Guitar Playing` | |
| Onde de choc | `Standing 2H Magic Area Attack 01` | ou 02 |
| Sorts lancés (éclair, flammes...) | `Standing 1H Magic Attack 01` | |
| Sort de soutien (bouclier, amplis) | `Standing 2H Cast Spell 01` | |
| Coup reçu | `Hit Reaction` | |
| Mort | `Dying` | |
| Glissade à genoux | `Running Slide` | |

## Utiles (si trouvées)

| Action | Recherche | Remarque |
|---|---|---|
| Stage Diving : élan | `Jump` | |
| Stage Diving : vol | `Falling Idle` | |
| Stage Diving : réception | `Falling To Landing` | |
| Victoire / fin de donjon | `Victory` ou `Cheering` | |
| Allongé sur le lit | `Sleeping Idle` ou `Laying Idle` | |
| Headbang / solo | `Headbang`, `Rock`, `Guitar` | prendre ce qui ressemble le plus |
| Marche d'Angus Young | `Duck Walk` | sinon faite dans Blender |

Les noms exacts peuvent varier : prendre l'animation la plus proche de la description.

## Étapes suivantes (faites par Claude, voir « État actuel »)

1. Conversion dans Blender : transfert de chaque animation Mixamo sur le squelette de Riffald,
   suppression du déplacement de la racine, export dans `riffald.glb`.
2. Godot : AnimationTree (machine à états, BlendSpace repos/marche/course selon la vitesse,
   frappe superposée sur le haut du corps), IK des mains sur la guitare, SpringBones cape/cheveux.
3. Héros personnalisés et PNJ : mêmes clips que Riffald, recopiés sur leur corps procédural (voir plus bas).

## État actuel (v0.1.14)

Conversion : `blender --background art/riffald/riffald.blend --python art/riffald/retarget_mixamo.py -- export`
(les passages retenus de chaque clip sont dans le dictionnaire `ANIMS` du script ;
`-- sheets <dossier> [noms]` produit des planches de contrôle image par image).

| Dans le jeu | Clip Mixamo (images) | Déclenché par |
|---|---|---|
| Repos | heroPose (fourni par Ulysse ; avant : Happy Idle) | immobile |
| Repos épuisé | Mutant Breathing Idle | vie ≤ 30 % |
| Marche / course | Walking, Running (en place) | vitesse (BlendSpace1D, accéléré au-delà de 2,9 m/s) |
| Frappe verticale | Great Sword High Spin Attack (26-47) | coup de guitare, en alternance |
| Coup diagonal | Great Sword Slash (4-34) | coup de guitare, en alternance |
| Onde de choc | Standing 2H Magic Area Attack 01 (21-62) | Onde de choc |
| Sort de soutien | Standing 2H Cast Spell 01 (8-60) | bouclier, amplis, phénix, growl, enceinte, pyrotechnie |
| Solo | headbang | mini-jeux de solo |
| Hochement de tête | headbang (extrait, tête et cou) | Riff, Accordage, esquive |
| Sursaut | Reaction (1-20, haut du corps) | coup reçu |
| Glissade | Running Slide (7-45) | Espace |
| Stage Diving | Falling Idle puis Falling To Landing (8-33) | talent Stage Diving |
| Victoire | Victory (10-115) | boss vaincu, Plumeau libéré |
| Allongé | Sleeping Idle (1-110) | lit de la taverne |
| Mort | Dying | mort |

Non utilisés : Guitar Playing, Jump, Standing 1H Magic Attack 02 (vrille), T-Pose.

Après l'animation, `HeroAnimator` (SkeletonModifier3D) porte la guitare à la sangle sur l'os
« chest » et ramène les mains dessus par IK à deux os ; pendant les frappes, la guitare passe dans
les mains, dans le prolongement des bras.

## Héros personnalisés et PNJ (v0.1.19)

Tous les personnages humanoïdes ont la posture et le déplacement de Riffald : `LocoAnimator` joue les
mêmes clips (heroPose, Mutant Breathing Idle, Walking, Running, même mélange que `HeroAnimator`) sur
une copie invisible du squelette de Riffald, sans maillage, puis les recopie sur le corps procédural
du personnage (`HumanoidBody`) :

- bassin, buste (axe bassin → cou), tête et pieds : rotation de l'os depuis sa pose de repos ;
- jambes et bras : IK à deux segments vers les chevilles et poignets de Riffald, à la longueur des
  membres procéduraux ; la foulée est à la taille du personnage (un ogre fait de plus grands pas) ;
- guitare en main : les bras restent sur la guitare (IK de HeroModel), le reste du corps suit les clips.

Concerne les héros personnalisés (création de personnage, coop), les clients de la taverne et les PNJ.

**Repos des PNJ (v0.1.30).** Les PNJ à corps procédural (clients, Gérald...) se reposent avec `pnjPose`
(style « pnj_corps », clip `idle_pnj` de `assets/animations/squelettes.glb`, mode `clips` du script) ;
Zarathos aussi (`idle` de son glb) ; Grokk le tavernier avec `Orc Idle`. Dans `retarget_mixamo.py`, un PNJ
importé peut prendre un clip source sous un autre nom (`CHARACTERS`, ex. `{"idle": "idle_orc", ...}`).
Gérald, Zarathos et l'Inconnue, autrefois des silhouettes figées, sont désormais des corps articulés
en costume (`Npc.COSTUMES` et `_dress`) : chapeau de paille et salopette, robe, chapeau pointu et
bâton tenu en main, long manteau et capuche.

Le corps procédural reprend la main pour les poses sans clip : assis (clients, fauteuil roulant),
solo, glissade, saut d'Angus Young, lit et mort.

## Ennemis humanoïdes (v0.1.20)

Les squelettes (soldats, capitaines, chef à la peau de loup) ont un corps articulé `HumanoidBody` :
repos et course de zombie (v0.1.21, voir ci-dessous), foulée à leur taille. Le coup d'épée garde son rythme
(élan, frappe, retour) : le bras de l'épée est amené par IK au-dessus de l'épaule puis devant, mélangé
avec la pose animée, et le poignet rabat la lame dans l'axe du bras à l'impact.

**Futurs ennemis humanoïdes** : dans `_build_model()`, construire le corps avec
`body = HumanoidBody.build(model, {proportions})` et accrocher les maillages à ses pivots
(`torso`, `head`, `hip_l`, `knee_l`, `ankle_l`, `upper_l`, `fore_l`, `hand_l`, et leurs pendants `_r`).
`Enemy._animate` l'anime alors tout seul ; une surcharge appelle `super(delta, moving)` puis ajoute ses
gestes (attaque, objet tenu) avec `body.reach()` et `HumanoidBody.orient_hand()`, comme `Skeleton`.

Coût : environ 0,05 ms par ennemi animé ; les ennemis des salles encore fermées sont endormis et ne
coûtent rien.

## Squelettes : repos et course de zombie (v0.1.21)

| Dans le jeu | Clip Mixamo | Remarque |
|---|---|---|
| Repos des squelettes | Zombie Idle | genoux fléchis, bras tendus devant |
| Déplacement des squelettes | Zombie Running (en place) | trottine à 1,6 m/s, cadence ajustée à leur vitesse |

Ces clips sont transférés sur le même squelette que Riffald mais exportés à part, sans maillage :
`blender --background art/riffald/riffald.blend --python art/riffald/retarget_mixamo.py -- clips`
→ `assets/animations/squelettes.glb` (dictionnaire `CLIPS` du script). LocoAnimator les ajoute comme
bibliothèque « squelettes » aux corps de style « zombie » (`HumanoidBody.style`, voir
`HeroAnimator.STYLES`). Un futur ennemi peut prendre ce style, ou un nouveau style avec ses propres clips.
