extends Node
## Bus de signaux global : découple le gameplay, l'interface et l'audio.
## N'importe quel script peut émettre ou écouter ces signaux via `Events.<signal>`.

@warning_ignore_start("unused_signal")

# --- Héros -----------------------------------------------------------------
signal hero_hp_changed(hp: int, max_hp: int)
signal hero_mana_changed(mana: float, max_mana: float)
signal hero_died
signal cooldown_started(skill_id: String, duration: float)
signal riff_combo(stack: int, multiplier: float)

# --- Progression -----------------------------------------------------------
signal xp_changed(xp: int, next_level_xp: int, level: int)
signal level_up(new_level: int)
signal gold_changed(gold: int)
signal potions_changed(count: int)
signal stats_changed
signal quest_updated(quest_id: String)

# --- Combat ----------------------------------------------------------------
signal enemy_killed(enemy: Node3D)
signal boss_health(boss_name: String, hp: int, max_hp: int)
signal boss_defeated(boss_id: String)

# --- Interactions & UI -----------------------------------------------------
signal toast(text: String, color: Color)
signal interaction_prompt(text: String)
signal dialogue_requested(npc_id: String)
signal dialogue_closed
signal solo_requested(mode: String, notes: int) # mode : "foudre" ou "endiable"
signal solo_finished(mode: String, hits: int, total: int)
signal solo_note_hit(mode: String, hits: int)
signal talents_changed
signal shield_changed(amount: int)
signal portal_opened
## Touche T : portail bleu de retour à la taverne (traité par le donjon).
signal town_portal_requested
## Choix de dialogue qui fait avancer l'histoire (ex. « gloubah_fight »), traité par le niveau.
signal story_action(action: String)
signal run_stats_changed

# --- Effets d'écran --------------------------------------------------------
signal screen_flash(color: Color, duration: float)
signal camera_shake(strength: float, duration: float)

@warning_ignore_restore("unused_signal")

const COLOR_DEFAULT := Color(0.93, 0.87, 0.72)
const COLOR_GOOD := Color(0.55, 0.95, 0.55)
const COLOR_BAD := Color(1.0, 0.4, 0.35)
const COLOR_GOLD := Color(1.0, 0.82, 0.3)
const COLOR_MAGIC := Color(0.72, 0.6, 1.0)


func notify(text: String, color: Color = COLOR_DEFAULT) -> void:
	toast.emit(text, color)
