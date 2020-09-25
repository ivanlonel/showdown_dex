-- name: create_schema#
-- Create the schema dex and all its base objects.
CREATE SCHEMA IF NOT EXISTS AUTHORIZATION dex;

--DROP SCHEMA IF EXISTS dex CASCADE;

--SET search_path = "$user";

DO $$ BEGIN
	CREATE TYPE type_stats_except_hp AS (
		atk numeric,
		def numeric,
		spa numeric,
		spd numeric,
		spe numeric
	);
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE type_stats AS (
		hp  smallint,
		atk smallint,
		def smallint,
		spa smallint,
		spd smallint,
		spe smallint
	);
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE type_boosts AS (
		atk smallint,
		def smallint,
		spa smallint,
		spd smallint,
		spe smallint,
		accuracy smallint,
		evasion smallint
	);
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE type_fling AS (
		base_power smallint,
		status text,
		volatile_status text
	);
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE enum_color AS ENUM('Green', 'Red', 'Blue', 'White', 'Brown', 'Yellow', 'Purple', 'Pink', 'Gray', 'Black');
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE enum_ability_slot AS ENUM('0', '1', 'H', 'S');
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	-- As specified both in class Species (pokemon-showdown/sim/dex-data.ts) and interface SpeciesData (pokemon-showdown/sim/global-types.ts)
	CREATE TYPE enum_evo_type AS ENUM('trade', 'useItem', 'levelMove', 'levelExtra', 'levelFriendship', 'levelHold', 'other');
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE enum_egg_group AS ENUM(
		'Ditto', 'Amorphous', 'Bug', 'Dragon', 'Fairy', 'Field', 'Flying', 'Grass',
		'Human-Like', 'Mineral', 'Monster', 'Water 1', 'Water 2', 'Water 3', 'Undiscovered'
	);
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE enum_nonstandard AS ENUM('Past', 'Future', 'Unobtainable', 'CAP', 'LGPE', 'Custom', 'Gigantamax');
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE enum_ternary AS ENUM('Never', 'Sometimes', 'Always');
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE enum_move_category AS ENUM('Physical', 'Special', 'Status');
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE enum_unreleased AS ENUM('false', 'true', 'Past');
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE enum_contest AS ENUM('Beautiful', 'Clever', 'Cool', 'Cute', 'Tough');
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	CREATE TYPE enum_move_source AS ENUM('M', 'T', 'L', 'R', 'E', 'D', 'S', 'V');
	COMMENT ON TYPE enum_move_source IS '{
		"M": "TM/HM",
		"T": "tutor",
		"L": "start or level-up; Column lvl must not be NULL.",
		"R": "restricted (special moves like Rotom moves)",
		"E": "egg",
		"D": "Dream World; Only 5D is valid.",
		"S": "event; Column event_index must not be NULL.",
		"V": "Virtual Console or Let''s Go transfer; Only 7V/8V is valid."
	}';
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
	-- Maybe turn this into a table (id, description)?
	CREATE TYPE enum_move_targets AS ENUM (
		'adjacentAlly',  -- Only relevant to Doubles or Triples, the move only targets an ally of the user.
		'adjacentAllyOrSelf',  -- The move can target the user or its ally.
		'adjacentFoe',  -- The move can target a foe, but not (in Triples) a distant foe.
		'all',  -- The move targets the field or all Pokémon at once.
		'allAdjacent',  -- The move is a spread move that also hits the user's ally.
		'allAdjacentFoes',  -- The move is a spread move.
		'allies',  -- The move affects all active Pokémon on the user's team.
		'allySide',  -- The move adds a side condition on the user's side.
		'allyTeam',  -- The move affects all unfainted Pokémon on the user's team.
		'any',  -- The move can hit any other active Pokémon, not just those adjacent.
		'foeSide',  -- The move adds a side condition on the foe's side.
		'normal',  -- The move can hit one adjacent Pokémon of your choice.
		'randomNormal',  -- The move targets an adjacent foe at random.
		'scripted',  -- The move targets the foe that damaged the user.
		'self'  -- The move affects the user of the move.
	);
	COMMENT ON TYPE enum_move_targets IS '{
		"adjacentAlly": "Only relevant to Doubles or Triples, the move only targets an ally of the user."
		"adjacentAllyOrSelf": "The move can target the user or its ally."
		"adjacentFoe": "The move can target a foe, but not (in Triples) a distant foe."
		"all": "The move targets the field or all Pokémon at once."
		"allAdjacent": "The move is a spread move that also hits the user''s ally."
		"allAdjacentFoes": "The move is a spread move."
		"allies": "The move affects all active Pokémon on the user''s team."
		"allySide": "The move adds a side condition on the user''s side."
		"allyTeam": "The move affects all unfainted Pokémon on the user''s team."
		"any": "The move can hit any other active Pokémon, not just those adjacent."
		"foeSide": "The move adds a side condition on the foe''s side."
		"normal": "The move can hit one adjacent Pokémon of your choice."
		"randomNormal": "The move targets an adjacent foe at random."
		"scripted": "The move targets the foe that damaged the user."
		"self": "The move affects the user of the move."
	}';
EXCEPTION
	WHEN duplicate_object THEN NULL;
END $$;



CREATE OR REPLACE FUNCTION to_id(text)
	RETURNS text
	IMMUTABLE
	STRICT
	PARALLEL SAFE
	LANGUAGE SQL
	--AS $$SELECT regexp_replace(lower(replace($1, ' ', '-')), '[^a-z0-9\-]+', '', 'g');$$;
	AS $$SELECT regexp_replace(lower($1), '[^a-z0-9]+', '', 'g');$$;

CREATE OR REPLACE FUNCTION camel_to_snake_case(text)
	RETURNS text
	IMMUTABLE
	STRICT
	PARALLEL SAFE
	LANGUAGE SQL
	AS $$SELECT lower(regexp_replace($1, '((?<=[a-z0-9])[A-Z]|(?!^)(?<!_)[A-Z](?=[a-z]))', '_\1', 'g'));$$;

CREATE OR REPLACE AGGREGATE product(numeric) (SFUNC=numeric_mul, STYPE=numeric);



CREATE TABLE IF NOT EXISTS nature (
	nature_name text PRIMARY KEY,
	decreased_stat text NOT NULL,
	increased_stat text NOT NULL,
	UNIQUE (decreased_stat, increased_stat)
);

CREATE TABLE IF NOT EXISTS generation (
	gen_id smallint PRIMARY KEY,
	gen_name text UNIQUE NOT NULL,
	games text[]
);

CREATE TABLE IF NOT EXISTS t_type (
	type_name text PRIMARY KEY,
	hp_ivs type_stats,  -- The IVs to get this Type Hidden Power (in gen 3 and later)
	hp_dvs type_stats  -- The DVs to get this Type Hidden Power (in gen 2)
);
COMMENT ON COLUMN t_type.hp_ivs IS 'The IVs to get this Type Hidden Power (in gen 3 and later)';
COMMENT ON COLUMN t_type.hp_dvs IS 'The DVs to get this Type Hidden Power (in gen 2)';

CREATE TABLE IF NOT EXISTS type_x_type (
	defending text REFERENCES t_type (type_name),
	attacking text REFERENCES t_type (type_name),
	multiplier numeric(2,1),  -- porperty damageTaken from original data: 0 = normal, 1 = weakness, 2 = resistance, 3 = immunity
	PRIMARY KEY (defending, attacking)
);

CREATE TABLE IF NOT EXISTS ability (
	ability_id text PRIMARY KEY,
	ability_name text UNIQUE NOT NULL,
	ability_num smallint UNIQUE NOT NULL,
	rating numeric,
	is_nonstandard enum_nonstandard,
	is_unbreakable boolean,
	suppress_weather boolean,
	on_critical_hit boolean,
	on_foe_try_eat_item boolean,
	on_damaging_hit_order numeric,
	on_residual_order numeric,
	on_residual_sub_order numeric,
	jb_condition jsonb
);

CREATE TABLE IF NOT EXISTS ability_priority (
	ability_id text PRIMARY KEY REFERENCES ability,
	on_accuracy_priority numeric,
	on_damaging_hit_order numeric,
	on_after_move_secondary_priority numeric,
	on_after_move_secondary_self_priority numeric,
	on_after_move_self_priority numeric,
	on_any_base_power_priority numeric,
	on_any_invulnerability_priority numeric,
	on_any_faint_priority numeric,
	on_ally_base_power_priority numeric,
	on_ally_modify_atk_priority numeric,
	on_ally_modify_spa_priority numeric,
	on_ally_modify_spd_priority numeric,
	on_attract_priority numeric,
	on_base_power_priority numeric,
	on_before_move_priority numeric,
	on_before_switch_out_priority numeric,
	on_boost_priority numeric,
	on_damage_priority numeric,
	on_drag_out_priority numeric,
	on_effectiveness_priority numeric,
	on_foe_base_power_priority numeric,
	on_foe_before_move_priority numeric,
	on_foe_modify_def_priority numeric,
	on_foe_redirect_target_priority numeric,
	on_foe_trap_pokemon_priority numeric,
	on_fractional_priority numeric,
	on_fractional_priority_priority numeric,
	on_hit_priority numeric,
	on_modify_accuracy_priority numeric,
	on_modify_atk_priority numeric,
	on_modify_crit_ratio_priority numeric,
	on_modify_def_priority numeric,
	on_modify_move_priority numeric,
	on_modify_priority_priority numeric,
	on_modify_spa_priority numeric,
	on_modify_spd_priority numeric,
	on_modify_type_priority numeric,
	on_modify_weight_priority numeric,
	on_redirect_target_priority numeric,
	on_residual_order numeric,
	on_residual_priority numeric,
	on_residual_sub_order numeric,
	on_source_base_power_priority numeric,
	on_source_invulnerability_priority numeric,
	on_source_modify_accuracy_priority numeric,
	on_source_modify_atk_priority numeric,
	on_source_modify_spa_priority numeric,
	on_switch_in_priority numeric,
	on_trap_pokemon_priority numeric,
	on_try_eat_item_priority numeric,
	on_try_heal_priority numeric,
	on_try_hit_priority numeric,
	on_try_move_priority numeric,
	on_try_primary_hit_priority numeric,
	on_type_priority numeric
);

CREATE TABLE IF NOT EXISTS ability_text (
	ability_id text PRIMARY KEY REFERENCES ability,
	ability_name text UNIQUE NOT NULL,
	short_desc text NOT NULL,
	descr text,
	short_desc_gen7 text,
	desc_gen7 text,
	short_desc_gen6 text,
	desc_gen6 text,
	short_desc_gen5 text,
	desc_gen5 text,
	short_desc_gen4 text,
	desc_gen4 text,
	short_desc_gen3 text,
	desc_gen3 text,
	start_txt text,
	end_txt text,
	activate text,
	activate_no_target text,
	add_item text,
	block text,
	boost text,
	cant text,
	damage text,
	move_txt text,
	change_ability text,
	transform_txt text,
	transform_end text
);


CREATE TABLE IF NOT EXISTS t_move (
	move_id text PRIMARY KEY,
	move_name text UNIQUE NOT NULL,
	move_num smallint NOT NULL,  -- All G-Max moves have the same "num". So do all Hidden Power types.
	is_nonstandard enum_nonstandard,
	jb_condition jsonb,
	base_power smallint NOT NULL,
	accuracy smallint,  -- if original accuracy property is TRUE, this becomes NULL and always_hit becomes TRUE
	always_hit boolean CHECK ((accuracy IS NULL) <> (always_hit IS NULL)),
	pp smallint NOT NULL,
	category enum_move_category NOT NULL,
	type_name text NOT NULL REFERENCES t_type,
	priority smallint NOT NULL,
	target enum_move_targets NOT NULL,
	real_move text REFERENCES t_move,  -- Hidden Power
	damage text,  -- number | 'level' | false | null
	contest_type enum_contest,
	no_pp_boosts boolean,
	is_z text,  -- REFERENCES item (item_id) DEFERRABLE INITIALLY DEFERRED,
	z_move jsonb,
	is_max boolean CHECK (is_max IS NULL OR is_gmax IS NULL), 
	is_gmax text,  -- REFERENCES pokemon (pokemon_id) DEFERRABLE INITIALLY DEFERRED,
	max_move_base_power smallint,
	ohko text,
	thaws_target boolean,
	heal numeric,  -- the original array represents numerator and denominator of a fraction
	force_switch boolean,
	self_switch text,
	self_boost type_boosts,
	selfdestruct text,
	breaks_protect boolean,
	recoil numeric,  -- the original array represents numerator and denominator of a fraction
	drain numeric,  -- the original array represents numerator and denominator of a fraction
	mind_blown_recoil boolean,
	steals_boosts boolean,
	struggle_recoil boolean,
	secondary_on_hit jsonb,  -- Originally either "secondary" or "secondaries" field (I think they can't coexist).
	self_on_hit jsonb,
	base_move_type text,
	base_power_modifier numeric,
	crit_modifier numeric,
	crit_ratio numeric,
	defensive_category enum_move_category,
	force_stab boolean,
	ignore_ability boolean,
	ignore_accuracy boolean,
	ignore_defensive boolean,
	ignore_evasion boolean,
	ignore_immunity jsonb,
	ignore_negative_offensive boolean,
	ignore_offensive boolean,
	ignore_positive_defensive boolean,
	ignore_positive_evasion boolean,
	multiaccuracy boolean,

	-- Originally a single field that could be a number or an array of 2 numbers (min, max)
	multihit_min smallint,
	multihit_max smallint,

	multihit_type text,
	no_damage_variance boolean,
	no_faint boolean,  -- False Swipe
	non_ghost_target enum_move_targets,
	pressure_target enum_move_targets,
	spread_modifier numeric,
	sleep_usable boolean,
	smart_target boolean,  -- Will change target if current target is unavailable. (Dragon Darts)
	tracks_target boolean,  -- Tracks original target through Ally Switch and other switch-out-and-back-in situations, rather than just targeting a slot. (Stalwart, Snipe Shot)
	use_target_offensive boolean,
	use_source_defensive_as_offensive boolean,
	will_crit boolean,
	has_crash_damage boolean,
	is_confusion_self_hit boolean,
	is_future_move boolean,
	--no_metronome text[],  -- The only row in which this wouldn't be NULL would be the Metronome move. Put this in another table or just discard it.
	no_sketch boolean,
	stalling_move boolean
);

CREATE TABLE IF NOT EXISTS move_flags (
	move_id text PRIMARY KEY REFERENCES t_move,
	authentic boolean,  -- Ignores a target's substitute.
	bite boolean,  -- Power is multiplied by 1.5 when used by a Pokemon with the Ability Strong Jaw.
	bullet boolean,  -- Has no effect on Pokemon with the Ability Bulletproof.
	charge boolean,  -- The user is unable to make a move between turns.
	contact boolean,  -- Makes contact.
	dance boolean,  -- When used by a Pokemon, other Pokemon with the Ability Dancer can attempt to execute the same move.
	defrost boolean,  -- Thaws the user if executed successfully while the user is frozen.
	distance boolean,  -- Can target a Pokemon positioned anywhere in a Triple Battle.
	gravity boolean,  -- Prevented from being executed or selected during Gravity's effect.
	heal boolean,  -- Prevented from being executed or selected during Heal Block's effect.
	mirror boolean,  -- Can be copied by Mirror Move.
	mystery boolean,  -- Unknown effect.
	nonsky boolean,  -- Prevented from being executed or selected in a Sky Battle.
	powder boolean,  -- Has no effect on Pokemon which are Grass-type, have the Ability Overcoat, or hold Safety Goggles.
	protect boolean,  -- Blocked by Detect, Protect, Spiky Shield, and if not a Status move, King's Shield.
	pulse boolean,  -- Power is multiplied by 1.5 when used by a Pokemon with the Ability Mega Launcher.
	punch boolean,  -- Power is multiplied by 1.2 when used by a Pokemon with the Ability Iron Fist.
	recharge boolean,  -- If this move is successful, the user must recharge on the following turn and cannot make a move.
	reflectable boolean,  -- Bounced back to the original user by Magic Coat or the Ability Magic Bounce.
	snatch boolean,  -- Can be stolen from the original user and instead used by another Pokemon using Snatch.
	sound boolean  -- Has no effect on Pokemon with the Ability Soundproof.
);
COMMENT ON COLUMN move_flags.authentic   IS 'Ignores a target''s substitute.';
COMMENT ON COLUMN move_flags.bite        IS 'Power is multiplied by 1.5 when used by a Pokemon with the Ability Strong Jaw.';
COMMENT ON COLUMN move_flags.bullet      IS 'Has no effect on Pokemon with the Ability Bulletproof.';
COMMENT ON COLUMN move_flags.charge      IS 'The user is unable to make a move between turns.';
COMMENT ON COLUMN move_flags.contact     IS 'Makes contact.';
COMMENT ON COLUMN move_flags.dance       IS 'When used by a Pokemon, other Pokemon with the Ability Dancer can attempt to execute the same move.';
COMMENT ON COLUMN move_flags.defrost     IS 'Thaws the user if executed successfully while the user is frozen.';
COMMENT ON COLUMN move_flags.distance    IS 'Can target a Pokemon positioned anywhere in a Triple Battle.';
COMMENT ON COLUMN move_flags.gravity     IS 'Prevented from being executed or selected during Gravity''s effect.';
COMMENT ON COLUMN move_flags.heal        IS 'Prevented from being executed or selected during Heal Block''s effect.';
COMMENT ON COLUMN move_flags.mirror      IS 'Can be copied by Mirror Move.';
COMMENT ON COLUMN move_flags.mystery     IS 'Unknown effect.';
COMMENT ON COLUMN move_flags.nonsky      IS 'Prevented from being executed or selected in a Sky Battle.';
COMMENT ON COLUMN move_flags.powder      IS 'Has no effect on Pokemon which are Grass-type, have the Ability Overcoat, or hold Safety Goggles.';
COMMENT ON COLUMN move_flags.protect     IS 'Blocked by Detect, Protect, Spiky Shield, and if not a Status move, King''s Shield.';
COMMENT ON COLUMN move_flags.pulse       IS 'Power is multiplied by 1.5 when used by a Pokemon with the Ability Mega Launcher.';
COMMENT ON COLUMN move_flags.punch       IS 'Power is multiplied by 1.2 when used by a Pokemon with the Ability Iron Fist.';
COMMENT ON COLUMN move_flags.recharge    IS 'If this move is successful, the user must recharge on the following turn and cannot make a move.';
COMMENT ON COLUMN move_flags.reflectable IS 'Bounced back to the original user by Magic Coat or the Ability Magic Bounce.';
COMMENT ON COLUMN move_flags.snatch      IS 'Can be stolen from the original user and instead used by another Pokemon using Snatch.';
COMMENT ON COLUMN move_flags.sound       IS 'Has no effect on Pokemon with the Ability Soundproof.';

CREATE TABLE IF NOT EXISTS t_move_text (
	move_id text PRIMARY KEY REFERENCES t_move,
	move_name text UNIQUE NOT NULL,
	short_desc text NOT NULL,
	descr text,
	short_desc_gen7 text,
	desc_gen7 text,
	short_desc_gen6 text,
	desc_gen6 text,
	short_desc_gen5 text,
	desc_gen5 text,
	short_desc_gen4 text,
	desc_gen4 text,
	short_desc_gen3 text,
	desc_gen3 text,
	short_desc_gen2 text,
	desc_gen2 text,
	short_desc_gen1 text,
	desc_gen1 text,
	start_txt text,
	start_gen1 text,
	start_from_item text,
	start_from_z_effect text,
	already_started text,
	end_txt text,
	end_from_item text,
	fail text,
	fail_select text,
	fail_too_heavy text,
	fail_wrong_forme text,
	activate text,
	add_item text,
	remove_item text,
	take_item text,
	block text,
	block_self text,
	boost text,
	clear_boost text,
	cant text,
	damage text,
	heal text,
	move_txt text,
	real_move text,
	prepare_txt text,
	switch_out text,
	change_ability text,
	type_change text,
	mega_no_item text,
	transform_txt text,
	upkeep text
);


CREATE TABLE IF NOT EXISTS base_species (
	species_num smallint PRIMARY KEY,
	species_name text NOT NULL
);

/*
 * Single-forme pokémon don't go in here (their forme_index in table "pokemon" should be NULL)
 * A Pokémon should be featured in here if and only if formeOrder contains at least 2 DISTINCT names
 * (Rockruff, Greninja, Zygarde and Minior have duplicates, for example. Rockruff shouldn't go in here)
 * Base formes of multi-forme pokémon DO go here, so that the table "pokemon" can reference them with a forme_index.
 */
CREATE TABLE IF NOT EXISTS pokemon_forme (
	species_num smallint REFERENCES base_species,
	forme_index smallint,
	forme_name text,  -- Originally either "forme" or "baseForme" field (they can't coexist). The flag is_base_forme differentiates between each case.
	pokemon_name text UNIQUE NOT NULL,  -- The original "name" field of the pokemon with this form OR the name that appears inside "cosmeticFormes"
	is_cosmetic boolean NOT NULL,
	is_base_forme boolean NOT NULL,  -- Not redundant. Minior's base forme's forme_index is 1 instead of 0.
    required_ability text REFERENCES ability (ability_id),
    required_move text REFERENCES t_move (move_id),
    is_battle_only boolean NOT NULL,  -- Originally either a string or an array (see Zygarde-Complete and Necrozma-Ultra). See table "pokemon_forme_battle_only".
    changes_from text REFERENCES pokemon_forme (pokemon_name),  -- Currently only differs from baseSpecies when dealing with Pikachu-Cosplay.
	PRIMARY KEY (species_num, forme_index)
);

/*
 * See the file FORMES.md in directory pokemon-showdown/data
 * 
 * This SHOULD contain only these kind of formes:
 * - "Regular" formes (Galarian and Alolan regional formes, Wormadam formes etc)
 * - Visual formes
 * - Formes changeable out-of-battle (this is where "changesFrom" property kicks in. May also have "requiredItem" property.)
 * - In-battle formes (this is where "battleOnly" property kicks in. May also have "requiredItem"/"requiredAbility"/"requiredMove" properties.)
 * - Visual in-battle formes (Cherrim, Cramorant, Mimikyu - Pokemon Showdown treats these like regular in-battle formes)
 * 
 * THIS SHOULD NOT contain these kind of formes:
 * - Cosmetic formes
 * - "Fake" visual in-battle formes (Dynamax/Gigantamax changes.)
 * - Event-only Ability formes (so Rockruff has 1 forme, Greninja has 2 and Zygarde has 3)
 * - Not formes (Alcremie sweets, Spinda patterns)

 * forme_index should follow the original formeOrder array.
 * Therefore, there may be holes in the sequence, since cosmetic formes appear in formeOrder array but not in this table
 */
CREATE TABLE IF NOT EXISTS pokemon (
    pokemon_id text PRIMARY KEY,  -- should always be = to_id(pokemon_name)
    species_num smallint NOT NULL REFERENCES base_species,
    forme_index smallint,  -- can't be part of a PRIMARY KEY because it can be null
    pokemon_name text UNIQUE NOT NULL,  -- not sure why even use an alias (pokemon_id) if this is UNIQUE and NOT NULL
    female_ratio numeric(4, 3) NOT NULL,  -- Use 'NaN' for genderless. Pokémon without gender info on original dataset can be presumed 50/50, I guess.
    base_stats type_stats NOT NULL,
    heightm numeric NOT NULL,
    weightkg numeric NOT NULL,
    color enum_color NOT NULL,
    can_hatch boolean,
    can_gigantamax text REFERENCES t_move (move_id),
    cannot_dynamax boolean,
    gen smallint REFERENCES generation (gen_id),
    unreleased_hidden enum_unreleased,  -- can be either 'false', 'true' or 'Past'.
    max_hp smallint,
    event_only boolean,
    UNIQUE (species_num, forme_index),
    FOREIGN KEY (species_num, forme_index) REFERENCES pokemon_forme
);

CREATE TABLE IF NOT EXISTS item (
	item_id text PRIMARY KEY,
	item_name text UNIQUE NOT NULL,
	item_num smallint,  -- position in this sheet: https://play.pokemonshowdown.com/sprites/itemicons-sheet.png?g8
	spritenum smallint,
	gen smallint,
	is_nonstandard enum_nonstandard,
	jb_condition jsonb,  -- not worth it.
	natural_gift_base_power smallint CHECK ((natural_gift_base_power IS NULL) = (natural_gift_type IS NULL)),
	natural_gift_type text REFERENCES t_type (type_name),
	mega_stone text REFERENCES pokemon (pokemon_id),
	mega_evolves text REFERENCES pokemon (pokemon_id),

	-- The two keys below are split from the "zMove" property in the original data source.
	is_generic_z_crystal boolean,  -- This is probably redundant, as z_move_type should be NOT NULL if and only if this is true.
	species_specific_z_move text REFERENCES t_move (move_id),

	z_move_type text REFERENCES t_type (type_name),
	z_move_from text REFERENCES t_move (move_id),
	forced_forme text REFERENCES pokemon (pokemon_id),
	ignore_klutz boolean,
	is_berry boolean,
	is_choice boolean,
	is_gem boolean,
	is_pokeball boolean,
	on_drive text REFERENCES t_type (type_name),
	on_memory text REFERENCES t_type (type_name),
	on_plate text REFERENCES t_type (type_name),
	fling type_fling,
	boosts type_boosts,
	on_take_item boolean,
	on_eat boolean,
	on_negate_immunity boolean
 );

ALTER TABLE t_move
	ADD FOREIGN KEY (is_z) REFERENCES item DEFERRABLE INITIALLY DEFERRED,
	ADD FOREIGN KEY (is_gmax) REFERENCES pokemon DEFERRABLE INITIALLY DEFERRED;  -- use pokemon_id instead?

CREATE TABLE IF NOT EXISTS item_user (
	item_id text REFERENCES item,
	pokemon_id text REFERENCES pokemon,
	PRIMARY KEY (item_id, pokemon_id)
);

CREATE TABLE IF NOT EXISTS item_priority (
	item_id text PRIMARY KEY REFERENCES item,
	on_accuracy_priority numeric,
	on_damaging_hit_order numeric,
	on_after_move_secondary_priority numeric,
	on_after_move_secondary_self_priority numeric,
	on_after_move_self_priority numeric,
	on_any_base_power_priority numeric,
	on_any_invulnerability_priority numeric,
	on_any_faint_priority numeric,
	on_ally_base_power_priority numeric,
	on_ally_modify_atk_priority numeric,
	on_ally_modify_spa_priority numeric,
	on_ally_modify_spd_priority numeric,
	on_attract_priority numeric,
	on_base_power_priority numeric,
	on_before_move_priority numeric,
	on_before_switch_out_priority numeric,
	on_boost_priority numeric,
	on_damage_priority numeric,
	on_drag_out_priority numeric,
	on_effectiveness_priority numeric,
	on_foe_base_power_priority numeric,
	on_foe_before_move_priority numeric,
	on_foe_modify_def_priority numeric,
	on_foe_redirect_target_priority numeric,
	on_foe_trap_pokemon_priority numeric,
	on_fractional_priority numeric,
	on_fractional_priority_priority numeric,
	on_hit_priority numeric,
	on_modify_accuracy_priority numeric,
	on_modify_atk_priority numeric,
	on_modify_crit_ratio_priority numeric,
	on_modify_def_priority numeric,
	on_modify_move_priority numeric,
	on_modify_priority_priority numeric,
	on_modify_spa_priority numeric,
	on_modify_spd_priority numeric,
	on_modify_type_priority numeric,
	on_modify_weight_priority numeric,
	on_redirect_target_priority numeric,
	on_residual_order numeric,
	on_residual_priority numeric,
	on_residual_sub_order numeric,
	on_source_base_power_priority numeric,
	on_source_invulnerability_priority numeric,
	on_source_modify_accuracy_priority numeric,
	on_source_modify_atk_priority numeric,
	on_source_modify_spa_priority numeric,
	on_switch_in_priority numeric,
	on_trap_pokemon_priority numeric,
	on_try_eat_item_priority numeric,
	on_try_heal_priority numeric,
	on_try_hit_priority numeric,
	on_try_move_priority numeric,
	on_try_primary_hit_priority numeric,
	on_type_priority numeric
);

CREATE TABLE IF NOT EXISTS pokemon_forme_required_item (
	species_num smallint,
	forme_index smallint,
	required_item text REFERENCES item (item_id),
	PRIMARY KEY (species_num, forme_index, required_item),
	FOREIGN KEY (species_num, forme_index) REFERENCES pokemon_forme
);

CREATE TABLE IF NOT EXISTS pokemon_forme_battle_only (
	species_num smallint,
	forme_index smallint,
	battle_only text REFERENCES pokemon (pokemon_id),
	PRIMARY KEY (species_num, forme_index, battle_only),
	FOREIGN KEY (species_num, forme_index) REFERENCES pokemon_forme
);

CREATE TABLE IF NOT EXISTS pokemon_egg_group (
	pokemon_id text REFERENCES pokemon,  -- Can't use only species_num. For example, Pikachu-Cosplay and Ash-Greninja differ in egg groups from their base forms.
	egg_group enum_egg_group,
	PRIMARY KEY (pokemon_id, egg_group)
);

CREATE TABLE IF NOT EXISTS pokemon_type (
	pokemon_id text REFERENCES pokemon,
	is_secondary boolean DEFAULT FALSE,  -- since there are only two possible values, why not use a boolean?
	type_name text NOT NULL REFERENCES t_type,
	PRIMARY KEY (pokemon_id, is_secondary),
	UNIQUE (type_name, pokemon_id)
);

CREATE TABLE IF NOT EXISTS pokemon_ability (
	pokemon_id text REFERENCES pokemon,
	ability_slot enum_ability_slot,
	ability_id text NOT NULL REFERENCES ability,
	PRIMARY KEY (pokemon_id, ability_slot),
	UNIQUE (ability_id, pokemon_id)
);

CREATE TABLE IF NOT EXISTS pokemon_evo (
	pokemon_id text REFERENCES pokemon,
	evo_id text PRIMARY KEY REFERENCES pokemon (pokemon_id),
	evo_level smallint,
    evo_type enum_evo_type,
    evo_item text REFERENCES item (item_id),
    evo_move text REFERENCES t_move (move_id),
    evo_condition text
);

CREATE TABLE IF NOT EXISTS pokemon_text (
	pokemon_id text PRIMARY KEY REFERENCES pokemon,
	pokemon_name text UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS item_text (
	item_id text PRIMARY KEY REFERENCES item,
	item_name text UNIQUE NOT NULL,
	short_desc text,
	descr text,
	desc_gen7 text,
	desc_gen6 text,
	desc_gen5 text,
	desc_gen4 text,
	short_desc_gen3 text,
	desc_gen3 text,
	desc_gen2 text,
	start_txt text,
	end_txt text,
	activate text,
	block text,
	damage text,
	heal text,
	transform_txt text
);


CREATE TABLE IF NOT EXISTS pokemon_event (
	pokemon_id text REFERENCES pokemon,
	event_index smallint,
	generation smallint REFERENCES generation (gen_id),
	lvl smallint,
	shiny enum_ternary,
	gender text,
	nature text REFERENCES nature (nature_name),
	ivs type_stats,
	perfect_ivs smallint,
	is_hidden boolean,
	max_egg_moves smallint,
	pokeball text REFERENCES item,
	--"from" text,
	PRIMARY KEY (pokemon_id, event_index)
);

CREATE TABLE IF NOT EXISTS pokemon_event_ability (
	pokemon_id text,
	event_index smallint,
	ability_id text REFERENCES ability,
	PRIMARY KEY (pokemon_id, event_index, ability_id),
	FOREIGN KEY (pokemon_id, event_index) REFERENCES pokemon_event
);

CREATE TABLE IF NOT EXISTS pokemon_event_move (
	pokemon_id text,
	event_index smallint,
	move_id text REFERENCES t_move,
	move_slot smallint CHECK (move_slot >= 0 AND move_slot <= 3),
	PRIMARY KEY (pokemon_id, event_index, move_id),
	FOREIGN KEY (pokemon_id, event_index) REFERENCES pokemon_event,
	UNIQUE (pokemon_id, event_index, move_slot)
);

CREATE TABLE IF NOT EXISTS learnset (
	learnset_id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
	pokemon_id text NOT NULL REFERENCES pokemon,
	move_id text NOT NULL REFERENCES t_move,
	generation smallint NOT NULL CHECK (generation = 5 OR source_id <> 'D'::enum_move_source),
	source_id enum_move_source NOT NULL CHECK (generation IN (7, 8) OR source_id <> 'V'::enum_move_source),
	event_index smallint CHECK ((source_id = 'S'::enum_move_source) <> (event_index IS NULL)),  -- XOR (will never be null because source_id can't be null)
	lvl smallint CHECK ((source_id = 'L'::enum_move_source) <> (lvl IS NULL)),  -- XOR (will never be null because source_id can't be null)
	UNIQUE (pokemon_id, move_id, generation, source_id, event_index),
	FOREIGN KEY (pokemon_id, event_index) REFERENCES pokemon_event
);

CREATE TABLE IF NOT EXISTS analysis (
	analysis_id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
	pokemon_id text NOT NULL REFERENCES pokemon,
	gen text NOT NULL REFERENCES generation (gen_name),
	lang text NOT NULL,
	format text NOT NULL,
	html_overview text,
	html_comments text,
	credits jsonb,
	UNIQUE (pokemon_id, gen, format, lang)
);

CREATE TABLE IF NOT EXISTS moveset (
	analysis_id integer REFERENCES analysis,
	moveset_index smallint,
	moveset_name text,
	pokemon text NOT NULL REFERENCES pokemon (pokemon_name),
	shiny boolean,
	gender text,
	lvl smallint,
	html_description text,
	PRIMARY KEY (analysis_id, moveset_index)
);

CREATE TABLE IF NOT EXISTS moveset_ability (
	analysis_id integer,
	moveset_index smallint,
	ability_name text REFERENCES ability (ability_name),
	PRIMARY KEY (analysis_id, moveset_index, ability_name),
	FOREIGN KEY (analysis_id, moveset_index) REFERENCES moveset
);

CREATE TABLE IF NOT EXISTS moveset_item (
	analysis_id integer,
	moveset_index smallint,
	item_name text REFERENCES item (item_name),
	PRIMARY KEY (analysis_id, moveset_index, item_name),
	FOREIGN KEY (analysis_id, moveset_index) REFERENCES moveset
);

CREATE TABLE IF NOT EXISTS moveset_move (
	analysis_id integer,
	moveset_index smallint,
	slot smallint CHECK (slot >= 0 AND slot <= 3),
	move_name text REFERENCES t_move (move_name),
	PRIMARY KEY (analysis_id, moveset_index, slot, move_name),
	FOREIGN KEY (analysis_id, moveset_index) REFERENCES moveset
);

CREATE TABLE IF NOT EXISTS moveset_evconfig (
	analysis_id integer,
	moveset_index smallint,
	evconfig type_stats,
	PRIMARY KEY (analysis_id, moveset_index, evconfig),
	FOREIGN KEY (analysis_id, moveset_index) REFERENCES moveset
);

CREATE TABLE IF NOT EXISTS moveset_ivconfig (
	analysis_id integer,
	moveset_index smallint,
	ivconfig type_stats,
	PRIMARY KEY (analysis_id, moveset_index, ivconfig),
	FOREIGN KEY (analysis_id, moveset_index) REFERENCES moveset
);

CREATE TABLE IF NOT EXISTS moveset_nature (
	analysis_id integer,
	moveset_index smallint,
	nature_name text REFERENCES nature,
	PRIMARY KEY (analysis_id, moveset_index, nature_name),
	FOREIGN KEY (analysis_id, moveset_index) REFERENCES moveset
);


CREATE OR REPLACE VIEW v_learnsets_including_prevos AS
	WITH RECURSIVE cte AS (
			SELECT
				*,
				NULL::integer AS original_id,
				0 AS recursive_depth
			FROM learnset
		UNION ALL
			SELECT
				NULL AS learnset_id,
				E.evo_id AS pokemon_id,
				C.move_id,
				C.generation,
				C.source_id,
				C.event_index,
				C.lvl,
				COALESCE(C.original_id, C.learnset_id) AS original_id,
				C.recursive_depth + 1
			FROM cte AS C
				INNER JOIN pokemon_evo AS E
					USING (pokemon_id)
	)
	SELECT DISTINCT ON (pokemon_id, move_id, generation, source_id, event_index)
		learnset_id,
		pokemon_id,
		move_id,
		generation,
		source_id,
		event_index,
		lvl,
		original_id
	FROM cte C
	ORDER BY pokemon_id, move_id, generation, source_id, event_index, recursive_depth;
--	WHERE NOT EXISTS (
--		SELECT 1
--		FROM cte X
--		WHERE (X.pokemon_id, X.move_id, X.generation, X.source_id) = (C.pokemon_id, C.move_id, C.generation, C.source_id)
--			AND X.event_index IS NOT DISTINCT FROM C.event_index
--			AND X.recursive_depth < C.recursive_depth
--	);


CREATE OR REPLACE VIEW v_nature_multipliers AS
	SELECT
		nature_name,
		jsonb_populate_record(
			NULL::type_stats_except_hp,
			jsonb_set(
				J,
				array[lower(increased_stat)],
				round((J->lower(increased_stat))::numeric*10/9, 1)::text::jsonb
			)
		) AS multipliers
	FROM nature,
		LATERAL jsonb_build_object(
			'atk', 1.0,
			'def', 1.0,
			'spa', 1.0,
			'spd', 1.0,
			'spe', 1.0,
			lower(decreased_stat), 0.9
		) J;

INSERT INTO nature VALUES
	('Hardy'  , 'Atk', 'Atk'),
	('Bold'   , 'Atk', 'Def'),
	('Modest' , 'Atk', 'SpA'),
	('Calm'   , 'Atk', 'SpD'),
	('Timid'  , 'Atk', 'Spe'),
	('Lonely' , 'Def', 'Atk'),
	('Docile' , 'Def', 'Def'),
	('Mild'   , 'Def', 'SpA'),
	('Gentle' , 'Def', 'SpD'),
	('Hasty'  , 'Def', 'Spe'),
	('Adamant', 'SpA', 'Atk'),
	('Impish' , 'SpA', 'Def'),
	('Bashful', 'SpA', 'SpA'),
	('Careful', 'SpA', 'SpD'),
	('Jolly'  , 'SpA', 'Spe'),
	('Naughty', 'SpD', 'Atk'),
	('Lax'    , 'SpD', 'Def'),
	('Rash'   , 'SpD', 'SpA'),
	('Quirky' , 'SpD', 'SpD'),
	('Naive'  , 'SpD', 'Spe'),
	('Brave'  , 'Spe', 'Atk'),
	('Relaxed', 'Spe', 'Def'),
	('Quiet'  , 'Spe', 'SpA'),
	('Sassy'  , 'Spe', 'SpD'),
	('Serious', 'Spe', 'Spe')
ON CONFLICT DO NOTHING;




-- name: create_temp_tables#
-- For testing purposes only
--CREATE TEMPORARY TABLE tmp_smogon_gens (obj jsonb);
--CREATE TEMPORARY TABLE tmp_typechart (obj jsonb);
--CREATE TEMPORARY TABLE tmp_abilities (obj jsonb);
--CREATE TEMPORARY TABLE tmp_moves (obj jsonb);
--CREATE TEMPORARY TABLE tmp_pokedex (obj jsonb);
--CREATE TEMPORARY TABLE tmp_items (obj jsonb);
--CREATE TEMPORARY TABLE tmp_learnsets (obj jsonb);
--CREATE TEMPORARY TABLE tmp_smogon_analyses (obj jsonb);



