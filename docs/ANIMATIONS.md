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

## Étapes suivantes (faites par Claude)

1. Conversion dans Blender : transfert de chaque animation Mixamo sur le squelette de Riffald,
   suppression du déplacement de la racine, export dans `riffald.glb`.
2. Godot : AnimationTree (machine à états, BlendSpace repos/marche/course selon la vitesse,
   frappe superposée sur le haut du corps), IK des mains sur la guitare, SpringBones cape/cheveux.
3. Le héros personnalisé garde l'animation procédurale en attendant un vrai modèle.
