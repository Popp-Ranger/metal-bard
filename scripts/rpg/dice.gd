class_name Dice
extends RefCounted
## Lancers de dés façon Donjons & Dragons.


## Lance `count` dés à `sides` faces et ajoute `bonus`. Ex. roll(2, 6, 3) = 2d6+3.
static func roll(count: int, sides: int, bonus: int = 0) -> int:
	var total := bonus
	for i in count:
		total += randi_range(1, sides)
	return total


static func d20() -> int:
	return randi_range(1, 20)


## Jet d'attaque : 1 = échec critique, 20 = coup critique.
## Renvoie 0 (raté), 1 (touché) ou 2 (critique).
static func attack_roll(bonus: int, target_ac: int) -> int:
	var natural := d20()
	if natural == 1:
		return 0
	if natural == 20:
		return 2
	return 1 if natural + bonus >= target_ac else 0
