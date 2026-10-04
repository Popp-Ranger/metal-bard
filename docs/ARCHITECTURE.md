# Architecture technique

## Vue d'ensemble

```
metal-bard/
├── project.godot              Configuration (autoloads, fenêtre 1600×900, rendu Forward+)
├── scenes/                    Scènes « racines » minimalistes (1 nœud + 1 script)
│   ├── main_menu.tscn
│   ├── tavern.tscn
│   └── dungeon.tscn
├── scripts/
│   ├── autoload/              Singletons chargés au démarrage
│   │   ├── events.gd          Bus de signaux global (Events)
│   │   ├── controls.gd        Actions d'entrée en touches physiques (Controls)
│   │   ├── game_state.gd      Fiche du héros, quêtes, inventaire, sauvegarde (GameState)
│   │   ├── sfx.gd             Sons synthétisés + ambiances (Sfx)
│   │   └── router.gd          Changements de scène avec fondu (Router)
│   ├── rpg/                   Données et règles (aucun nœud)
│   │   ├── race_db.gd         Races, options d'apparence, bonus raciaux
│   │   ├── talent_db.gd       Arbre de talents (5 branches × 4 paliers)
│   │   ├── balance.gd         TOUTES les valeurs d'équilibrage
│   │   ├── dice.gd            Dés D&D
│   │   ├── character_stats.gd Caractéristiques / modificateurs
│   │   ├── item_db.gd         Reliques
│   │   ├── quest_db.gd        Quêtes
│   │   └── dialogue_db.gd     Dialogues des PNJ
│   ├── actors/                Héros, ennemis, PNJ
│   ├── combat/                Effets de sorts (éclairs, onde, tempête, vague, zones)
│   ├── world/                 Niveaux, génération, décor, caméra, portail, butin
│   └── ui/                    HUD, dialogues, mini-jeu, fiche, menu
├── shaders/                   Mur de pierre + découpe, post-traitement, portail
├── tests/                     Test de fumée automatisé + scène vitrine
└── docs/                      GDD, architecture, feuille de route, captures
```

## Principes

1. **Tout en code, scènes minimales.** Chaque scène `.tscn` ne contient qu'un nœud racine et son script ; décors, personnages et interface sont construits par code à partir de primitives (`Visuals`). Avantages : diff Git lisibles, aucune scène corrompue, génération procédurale naturelle. Quand les vrais modèles 3D arriveront, on remplacera les fonctions `_build_model()` par l'instanciation d'un `.glb`.
2. **Données séparées de la logique.** Quêtes, dialogues, objets et équilibrage vivent dans `scripts/rpg/`. Ajouter du contenu ne demande pas de toucher au moteur de jeu.
3. **Communication par signaux.** Le gameplay émet (`Events.enemy_killed`, `Events.solo_requested`…), l'interface et l'audio écoutent. Aucun script de gameplay ne connaît le HUD.
4. **Typage statique strict.** Tout le GDScript est typé (compatible avec l'option « avertissements traités comme erreurs »). On évite `:=` sur les valeurs `Variant` (accès à un dictionnaire, `clamp()`, `max()`…) et on utilise les versions typées (`clampf`, `maxi`, `roundi`…).

## Autoloads

| Nom | Rôle |
|---|---|
| `Events` | Signaux globaux + `Events.notify(texte, couleur)` pour les messages à l'écran |
| `Controls` | Crée les actions d'entrée (touches physiques → AZERTY/QWERTY) ; `Controls.key_label("interact")` donne la lettre réelle |
| `GameState` | Fiche D&D, PV, dB, or, potions, reliques, états de quêtes, drapeaux, sauvegarde JSON (`user://metal_bard_save.json`) |
| `Sfx` | `Sfx.play("zap", -8.0)`, `Sfx.play_ambience("amb_dungeon")` |
| `Router` | `Router.go_to(Router.DUNGEON)` avec fondu au noir |

## Acteurs

- **`HeroModel`** : apparence construite depuis `GameState.appearance` (race, sexe, cornes, défenses, barbe, coiffure) ; `set_appearance()` reconstruit le modèle (écran de création).
- **`TalentCaster`** (enfant du héros) : les 10 sorts actifs et les passifs de l'arbre de talents.
- **`Hero`** (`CharacterBody3D`, mode flottant) : déplacement relatif à la caméra iso, visée souris, compétences, interaction avec le groupe `"interactable"` (tout nœud ayant `interact_radius`, `get_prompt()` et `interact(hero)`).
- **`Enemy`** (base) : machine à états Errance / Poursuite / Attaque / Sonné / Mort, jets D&D, recul, barre de vie, butin. Les sous-classes surchargent `_configure()`, `_build_model()`, `_animate()`, `_attack_anim()` et éventuellement `_update_special()` :
  - `Skeleton` (+ variante `captain`)
  - `FrogBoss` (vague, bond, phase 2, invocations)
- **`Npc`** : PNJ de taverne ; l'apparence dépend de son `npc_id`, le texte vient de `DialogueDB`.

## Niveaux

`Level` (base) installe l'environnement, la caméra `IsoCamera`, le post-traitement `PostFx` et le `Hud`, puis fait apparaître le héros.
- **`tavern.gd`** : construit la salle (murs, fenêtres, plancher, comptoir, tables, chaises, lanternes, cheminée, escalier, tableau des quêtes, cercle de runes) et place les PNJ.
- **`dungeon.gd`** : appelle `DungeonGenerator`, construit sol et murs en `MultiMesh` (quelques draw calls pour des milliers de blocs), une seule `StaticBody3D` pour les collisions, décore, peuple et gère la fin de quête. Son **thème** (`cfg["theme"]` : « catacombes », « crypte », « temple ») règle le sol, les murs, le décor (`DungeonThemes` : lave, vitraux, bancs, fontaine de sang), les ennemis, la salle du fond et les sorties.
- **`crypt.gd`** (hérite de `dungeon.gd`) : les Cryptes de la Cathédrale, portail à XP, régénérées à chaque passage (`GameState.crypt_seed`, partagée en coop), ennemis au niveau du héros.
- **`temple.gd`** : le Temple du Dragon (chapitre 2) : esplanade et marches, parvis, façade à tête de dragon, orage, Back Jlack et son épreuve (mini-jeu « epreuve »).
- **`LegendCinematic`** (`scripts/ui`) : la cinématique de la légende (visage de Back Jlack dans un `SubViewport`, orage).

## Ajouter du contenu

### Une nouvelle quête
1. Ajouter l'entrée dans `QuestDB.QUESTS` (titre, donneur, objectifs, `requires`, configuration du donjon, récompense).
2. Écrire les dialogues du donneur dans `DialogueDB` selon `GameState.quest_state(id)`.
3. Si le boss est nouveau : créer une sous-classe d'`Enemy` et la choisir dans `dungeon.gd` selon `cfg["boss"]`.

### Un nouvel ennemi
Créer `scripts/actors/mon_ennemi.gd` qui `extends Enemy`, surcharger `_configure()` (stats) et `_build_model()` (apparence), puis l'ajouter à `_spawn_enemies()`.

### Une nouvelle relique
Ajouter une entrée dans `ItemDB.ITEMS` (et dans `COMMON_DROPS` si elle peut tomber des monstres). Les bonus s'appliquent automatiquement via `GameState.ability()`.

### Un nouveau sort
Ajouter une méthode `cast_xxx()` dans `hero.gd`, une action dans `Controls.KEY_ACTIONS`, une entrée dans `Hud.SKILLS`, ses constantes dans `Balance` et, si besoin, un effet visuel dans `scripts/combat/`.

## Tests

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn
```
Vérifie les formules D&D, génère 50 donjons (connexité départ → boss), puis joue la quête complète : taverne, acceptation, portail, donjon, sorts, mort de tous les ennemis et du boss, portail de retour, récompense, sauvegarde / chargement. Code de sortie 0 = succès.

La scène `tests/showcase.tscn` rejoue une séquence scriptée ; avec le *Movie Maker* de Godot elle produit les captures de `docs/screenshots/` :
```bash
Godot_v4.7.2-stable_win64_console.exe --path . --write-movie captures/frame.png --fixed-fps 30 res://tests/showcase.tscn
```

## Chemin vers le multijoueur
1. Passer `GameState` en « état par joueur » (`PlayerState`) indexé par l'identifiant réseau.
2. `MultiplayerSpawner` pour héros, ennemis, butin ; `MultiplayerSynchronizer` pour positions et PV.
3. Les ennemis ne tournent que sur le serveur (`is_multiplayer_authority()`), les clients reçoivent l'état.
4. Les compétences deviennent des RPC `@rpc("any_peer", "call_local")` validées par le serveur (coût, recharge).
5. Le mini-jeu du solo reste local ; seul son résultat (notes réussies) est envoyé.
