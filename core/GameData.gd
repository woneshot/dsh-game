extends Node
## Static gameplay data: skills and bosses for Flesh Pact.


## Skill catalog, keyed by skill id. Cost is paid from the player's energy.
const SKILLS: Dictionary = {
	"cleave": {
		"title": "Cleave",
		"cost": 1,
		"damage": 6,
		"description": "Deal 6 damage.",
	},
	"guard": {
		"title": "Guard",
		"cost": 1,
		"shield": 6,
		"description": "Gain 6 shield.",
	},
	"war_cry": {
		"title": "War Cry",
		"cost": 1,
		"buff": 3,
		"description": "Next attack deals +3 damage.",
	},
	"mend": {
		"title": "Mend",
		"cost": 2,
		"heal": 10,
		"description": "Restore 10 HP.",
	},
}


## Boss catalog, keyed by boss id.
const BOSSES: Dictionary = {
	"goblin_chief": {
		"name": "Goblin Chief",
		"max_hp": 80,
		"attack": 8,
	},
	"iron_golem": {
		"name": "Iron Golem",
		"max_hp": 120,
		"attack": 10,
	},
	"shadow_wyvern": {
		"name": "Shadow Wyvern",
		"max_hp": 150,
		"attack": 12,
	},
}


## Bosses fought in this order during one run.
const BOSS_SEQUENCE: Array[String] = ["goblin_chief", "iron_golem", "shadow_wyvern"]
