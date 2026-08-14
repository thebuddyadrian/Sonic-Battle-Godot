# Sonic Battle Godot Project - Planned Folder Structure

This document details my recommended folder structure for the project given the game's design goals (open source, mod support, etc.). This proposal is just a suggestion to guide the team as we create this project, and should not be treated as a strict set of rules. As this project is developed, we may decide to change some things as we see fit.

**By thebuddyadrian**

## Design Philosophies
### Separate Engine Assets from Game Content

**Engine Assets:** Assets and code that make up the core of the engine and will be used to create the game’s content. 
- Base Classes/Scenes: Base class scripts/scenes that will be inherited from to create content for the game, such as characters  (Base Entity, Base Character, Base Stage, etc.)
- Reusable Common Nodes: (Custom sprite node, state machine)
- Autoloaded scripts
- Custom resource types

**Game Content**: Content of the game that will built using the **Engine Assets**.
- Fighters
- Stages
- Data (Character List, Stage List)

### Each piece of content should be self-contained

For each fighter/stage, its content should be contained inside its own folder. This means related sprites, audio, scripts, etc. should be inside the fighter/stage's folder. Fighters/Stages should **not** depend on anything outside its folder, **unless it's inside the `engine/` folder** (engine assets are assumed to be accessible by all game content).

This will allow us to create the game in a way that all content can be exported as a standalone resource. This is important for **mod support** as we want modded content to be created/loaded in the same exact way as base game content.

## Folder Structure

```
addons/ # Third party addons and EditorPlugins, required to be here by Godot (If it wasn't, I'd put it in engine/, but I can't do that).

engine/ # Core engine code that the game will build off of and depend on.
	assets/ # Raw assets used throughout the project
		environment/
			battle_style_environment.tres
		fonts/
		shaders/
		audio/
			sfx/ # Sound effects
				battle/ # Non character-specific Sounds that will be used during gameplay.
				ui/ # Sounds that will be used in menus and UI
	autoload/ # Autoloaded scripts
		game_data.gd # Autoload to access game data, such as the list of fighters, stages, etc.
		controls.gd # Autoload that handles saving, loading, and editing custom controls
		match_setup.gd # Autoload that stores the selections used for a match, such as stage selections, character selections for each player, input devices for each player, etc.
	bases/ # Base classes/scenes for characters, stages, and other game content
		base_entity.gd # Base class for 2.5D Sonic Battle-style gameplay actors
		base_character/ # Base class for playable fighters
			states/ # States shared between all characters
				idle.gd
				move.gd
				...
				base_attack.gd # Base class for creating an attack state using attack "phases"/"windows", Rivals of Aether style
			base_character.gd # Base class that will be inherited to create new character scripts
			base_character.tscn # Base scene that can be inherited to create new character scenes
			character_ai.gd # Base CPU/AI opponent behaviour script. Will be inherited by characters to create character-specific AI.
			character_animation.gd # Abstract class for creating a scene containing a character's visual components.
		base_spawnable.gd # Base class for spawnable objects, can be extended to create custom spawnable types that don't fit under projectile or trap.
		base_projectile.gd # Base class for simple projectiles that move in a direction and hit players. Extends from BattleSpawnable
		base_trap.gd # Base class for spawnables that stay in place until activate. Extends from BattleSpawnable
		base_effect.gd # Base class for visual effects that can be spawned
		base_stage.gd # Base class for battle stages
	effects/
		heal_effect.tscn
	parts/ # Custom node types and scenes that will be used throughout the project
		battle_animated_sprite_3d.gd  # Custom AnimatedSprite3D class that can display a different image based on the rotation of the camera viewing it.
		battle_sprite_3d.gd # Same as above, but for plain Sprite3D
		hitbox.gd # Custom Area2D class that can damage hurtboxes
		hurtbox.gd # Custom Area2D class that can be damaged by hitboxes
		player_camera/ # Camera scene that will track the player and can be rotated by the player by holding guard.
			player_camera.tscn
			player_camera.gd
		player_window.tscn # A scene that defines the configuration for a player sub-window when launching multiple windows
		state_machine/
			state_machine.gd # Node that handles processing states defined by child State nodes
			state.gd # Base class for creating a StateMachine state
	resource_types/ # Custom resource classes to hold info for various types of game content
		attack_info.gd # Resource class to define attack properties like frame data, animation, etc.
		hit_info.gd # Resource class to define the properties of a hitbox
		character_info.gd # Resource class to define character info like display name, stats, etc.
		stage_info.gd # Resource class to define stage info
		projectile_info.gd # Resource class to define a simple projectile that simply moves and has a hitbox. More advanced projectiles will need a custom script.
		data_list.gd # Base class for a list of game content, simply holds a PackedStringArray (used by character_list.tres and stage_list.tres in data/)
	match_scene/ # Scene where battle gameplay happens. Loads stage and characters, and manages the flow of the game.
		match_scene.gd
		match_scene.tscn
	ui/
		player_hud/
		pause_screen/
		skill_select/
		controls_settings/
		story/ # Core stuff for creating visual novel-esque story content?? Idk, not sure how the story is gonna work
	script_templates/ # Templates for creating new scripts like Character scripts, Attack scripts, State scripts, etc.


characters/ # Playable characters that will be created using the BaseCharacter class
	sonic/ (example character folder structure)
		sonic.tscn # Character scene
		sonic_animation.tscn # Scene containing only animation-related nodes, 
							 # to show sprites in results screen and skill select menu
		sonic.tres # CharacterInfo resource defining display name, stats, etc.
		sonic.gd # Character script
		sonic_ai.gd # Character AI script, for AI opponents. Inherits from engine/bases/base_character/character_ai.gd
		sprites/ # Character sprites
			sonic_sprite_sheet.png
			sonic_portrait.png
			sonic_life_icon.png
			sonic_effects.png
		audio/ # Character-specific sound effects and voice clips. Universal sounds will be in engine/assets/audio
			sound/ 
			voice/
		states/ # Character-specific movement states like air action and dash. 
				# Can also override general states like Idle and Move for custom behaviour.
			air_action.gd
			dash.gd
		attacks/
			jab_1.tres # AttackInfo resource defining an attack, will be attached to a BaseAttack state node.
			jab_2.tres
			jab_3.tres
			heavy.tres 
			heavy.gd # Some attacks may also have a custom script, but its not required.
		spawnables/ # For spawnable objects like projectiles and traps.
			sonic_grnd_shot/
				sonic_grnd_shot.tscn
				sonic_grnd_shot.gd
	tails/
	knuckles/
	shadow/
data/ # Contains data about this specific game, such as the list of characters/stages
	character_list.tres # List of string identifiers for characters ("sonic", "tails", "knuckles", "shadow"). Instance of engine/resource_types/data_list.gd
	stage_list.tres # List of string identifiers for stages. Instance of engine/resource_types/data_list.gd
effects/ # Visuals effects that will be spawned by characters
menus/ # Game menus like Title Screen, Mode Select, Character Select, etc.
	_common/
mod_export/ # Where mods will be exported as PCK
music/ # Stores BGM used in the game
stages/ # Battle stages that will be created by importing a model and attaching a BattleStage script to it.
story/ # Will store story assets made with Dialogic
```
