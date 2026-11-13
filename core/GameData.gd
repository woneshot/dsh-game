extends Node
## Static gameplay data: skills and bosses.


## Skill catalog, keyed by skill id.
const SKILLS: Dictionary = {
	"slash": {
		"title": "Slash",
		"cost": 1,
		"damage": 6,
		"description": "Deal 6 damage.",
	},
	"heavy_blow": {
		"title": "Heavy Blow",
		"cost": 2,
		"damage": 12,
		"description": "Deal 12 damage.",
	},
	"block": {
		"title": "Block",
		"cost": 1,
		"shield": 5,
		"description": "Gain 5 shield.",
	},
	"heal": {
		"title": "Heal",
		"cost": 2,
		"heal": 8,
		"description": "Restore 8 HP.",
	},
}


## Boss catalog, keyed by boss id.
const BOSSES: Dictionary = {
	"goblin_chief": {
		"name": "Goblin Chief",
		"max_hp": 80,
	},
	"iron_golem": {
		"name": "Iron Golem",
		"max_hp": 120,
	},
	"shadow_wyvern": {
		"name": "Shadow Wyvern",
		"max_hp": 150,
	},
}
