-- name: populate_generation!
-- Exoects all elements in a single jsonb object.
INSERT INTO generation (gen_id, gen_name, games)
	SELECT pos, elem->>'shorthand', string_to_array(elem->>'name', '/')
	FROM tmp_smogon_gens,
		LATERAL jsonb_array_elements(obj) WITH ORDINALITY arr(elem, pos);

DROP TABLE IF EXISTS tmp_smogon_gens;



-- name: populate_types#
-- Populate tables t_type and type_x_type.
INSERT INTO t_type (type_name, hp_ivs, hp_dvs)
	SELECT
		obj->>'alias',
		jsonb_populate_record(null::type_stats, obj->'HPivs'),
		jsonb_populate_record(null::type_stats, obj->'HPdvs')
	FROM tmp_typechart;

INSERT INTO type_x_type (defending, attacking, multiplier)
	SELECT
		obj->>'alias',
		ATK.type_name,
		CASE ATK.value
			WHEN '0' THEN 1
			WHEN '1' THEN 2
			WHEN '2' THEN 0.5
			WHEN '3' THEN 0
		END
	FROM tmp_typechart,
		LATERAL jsonb_each_text(obj->'damageTaken') AS ATK(type_name, value)
	WHERE EXISTS (SELECT 1 FROM t_type T WHERE ATK.type_name = T.type_name);

DROP TABLE IF EXISTS tmp_typechart;



-- name: populate_abilities#
-- Populate tables ability and ability_priority.
INSERT INTO ability
	SELECT (jsonb_populate_record(null::ability, jsonb_object_agg(camel_to_snake_case(k), v) || jsonb_with_renamed_keys)).*
	FROM tmp_abilities,
		LATERAL jsonb_each(obj - '{alias, name, num, condition}'::text[]) AS J(k, v),
		LATERAL jsonb_build_object(
			'ability_id', obj->'alias',
			'ability_name', obj->'name',
			'ability_num', obj->'num',
			'jb_condition', obj->'condition'
		) AS jsonb_with_renamed_keys
	GROUP BY jsonb_with_renamed_keys;

INSERT INTO ability_priority
	SELECT (jsonb_populate_record(null::ability_priority, json_rec)).*
	FROM (
		SELECT (jsonb_object_agg(camel_to_snake_case(k), v) || jsonb_with_renamed_keys) AS json_rec
		FROM tmp_abilities,
			LATERAL jsonb_each(
				obj - '{alias, onAllyModifySpAPriority, onAllyModifySpDPriority, onModifySpAPriority, onModifySpDPriority, onSourceModifySpAPriority}'::text[]
			) AS J(k, v),
			LATERAL jsonb_build_object(
				'ability_id', obj->'alias',
				'on_ally_modify_spa_priority', obj->'onAllyModifySpAPriority',
				'on_ally_modify_spd_priority', obj->'onAllyModifySpDPriority',
				'on_modify_spa_priority', obj->'onModifySpAPriority',
				'on_modify_spd_priority', obj->'onModifySpDPriority',
				'on_source_modify_spa_priority', obj->'onSourceModifySpAPriority'
			) AS jsonb_with_renamed_keys
		GROUP BY jsonb_with_renamed_keys
	) AS S
	WHERE NOT jsonb_populate_record(null::ability_priority, json_rec - 'ability_id') IS NULL;

DROP TABLE IF EXISTS tmp_abilities;


-- name: populate_abilities_text!
-- Populate table ability_text.
INSERT INTO ability_text
	SELECT (jsonb_populate_record(null::ability_text, jsonb_object_agg(camel_to_snake_case(k), v) || jsonb_with_renamed_keys)).*
	FROM tmp_abilities_text,
		LATERAL jsonb_each(obj - '{alias, name, desc, start, end, move, transform}'::text[]) AS J(k, v),
		LATERAL jsonb_build_object(
			'ability_id', obj->'alias',
			'ability_name', obj->'name',
			'descr', obj->'desc',
			'start_txt', obj->'start',
			'end_txt', obj->'end',
			'move_txt', obj->'move',
			'transform_txt',  obj->'transform'
		) AS jsonb_with_renamed_keys
	GROUP BY jsonb_with_renamed_keys;

DROP TABLE IF EXISTS tmp_abilities_text;



-- name: populate_moves#
-- Populate tables t_move and move_flags.
INSERT INTO t_move
	SELECT (jsonb_populate_record(null::t_move, jsonb_object_agg(camel_to_snake_case(k), v) || jsonb_with_renamed_keys || CASE
			WHEN jsonb_typeof(obj->'isMax') = 'boolean' THEN jsonb_build_object('is_max', obj->'isMax')
			ELSE jsonb_build_object('is_gmax', to_id(obj->>'isMax'))
		END)).*
	FROM tmp_moves,
		LATERAL jsonb_each(obj - '{alias, name, num, condition, accuracy, type, realMove, isMax, heal, recoil, drain, secondary, secondaries, multihit, flags}'::text[]) AS J(k, v),
		LATERAL jsonb_build_object(
			'move_id', obj->'alias',
			'move_name', obj->'name',
			'move_num', obj->'num',
			'jb_condition', obj->'condition',
			CASE obj->>'accuracy' WHEN 'true' THEN 'always_hit' ELSE 'accuracy' END, obj->'accuracy',
			'type_name', obj->'type',
			'real_move', to_id(obj->>'realMove'),
			'heal', (obj->'heal'->0)::numeric / (obj->'heal'->1)::numeric,
			'recoil', (obj->'recoil'->0)::numeric / (obj->'recoil'->1)::numeric,
			'drain', (obj->'drain'->0)::numeric / (obj->'drain'->1)::numeric,
			'secondary_on_hit', COALESCE(obj->'secondary', obj->'secondaries'),
			'multihit_min', CASE WHEN jsonb_typeof(obj->'multihit') = 'array' THEN obj->'multihit'->0 ELSE obj->'multihit' END,
			'multihit_max', CASE WHEN jsonb_typeof(obj->'multihit') = 'array' THEN obj->'multihit'->1 ELSE obj->'multihit' END
		) AS jsonb_with_renamed_keys
	GROUP BY jsonb_with_renamed_keys, obj;

INSERT INTO move_flags 
	SELECT (jsonb_populate_record(null::move_flags, jsonb_set(obj->'flags', '{move_id}', obj->'alias'))).*
	FROM tmp_moves
	WHERE obj->'flags' @? '$.*';  -- obj->'flags' IS NOT NULL AND obj->'flags' <> '{}'::jsonb;

DROP TABLE IF EXISTS tmp_moves;


-- name: populate_moves_text!
-- Populate table t_move_text.
INSERT INTO t_move_text
	SELECT (jsonb_populate_record(null::t_move_text, jsonb_object_agg(camel_to_snake_case(k), v) || jsonb_with_renamed_keys)).*
	FROM tmp_moves_text,
		LATERAL jsonb_each(obj - '{alias, name, desc, start, end, move, prepare, transform}'::text[]) AS J(k, v),
		LATERAL jsonb_build_object(
			'move_id', obj->'alias',
			'move_name', obj->'name',
			'descr', obj->'desc',
			'start_txt', obj->'start',
			'end_txt', obj->'end',
			'move_txt', obj->'move',
			'prepare_txt', obj->'prepare',
			'transform_txt',  obj->'transform'
		) AS jsonb_with_renamed_keys
	WHERE obj->>'alias' <> 'magikarpsrevenge'
	GROUP BY jsonb_with_renamed_keys;

DROP TABLE IF EXISTS tmp_moves_text;



-- name: populate_pokedex#
-- Populate tables related to pokemon and items.
INSERT INTO base_species(species_num, species_name)
	SELECT
		(obj->'num')::smallint,
		replace(obj->>'name', E'\u2019', '''')  -- Farfetch’d > Farfetch'd
	FROM tmp_pokedex
	WHERE obj->'forme' IS NULL;

INSERT INTO pokemon_forme (species_num, forme_index, forme_name, pokemon_name, is_cosmetic, is_base_forme, required_ability, required_move, is_battle_only, changes_from)
	SELECT
		species_num,
		forme_index,
		COALESCE(obj->>'forme', obj->>'baseForme', SUBSTRING(pokemon_name FROM base_forme || '-(.+)')),
		replace(pokemon_name, E'\u2019', ''''),  -- Farfetch’d > Farfetch'd
		obj IS NULL OR obj->'cosmeticFormes' IS NOT NULL AND obj->'cosmeticFormes' ? pokemon_name,
		obj->'formeOrder' IS NOT NULL,
		A.ability_id,
		M.move_id,
		obj->'battleOnly' IS NOT NULL,
		obj->>'changesFrom'
	FROM (
		SELECT
			(obj->'num')::smallint AS species_num,
			obj->>'name' AS base_forme,
			U.ordinal - 1 AS forme_index,
			U.pokemon_name
		FROM tmp_pokedex,
			LATERAL (  -- this subquery's purpose is to remove duplicates (like Minior, Rockruff, Greninja and Zygarde) before assigning definitive ordinals
				SELECT array_agg(value ORDER BY ordinality) AS list
				FROM (
					SELECT DISTINCT ON (value) value, ordinality
					FROM jsonb_array_elements_text(obj->'formeOrder') WITH ORDINALITY  -- col name defaults: "value", "ordinality"
					ORDER BY value, ordinality
				) AS S
			) AS D,
			LATERAL unnest(D.list) WITH ORDINALITY AS U(pokemon_name, ordinal)
		WHERE array_length(D.list, 1) > 1  -- bye bye, Rockruff!
	) AS all_formes
		LEFT JOIN tmp_pokedex AS TP
			ON all_formes.pokemon_name = TP.obj->>'name'
		LEFT JOIN ability AS A
			ON TP.obj->>'requiredAbility' = A.ability_name
		LEFT JOIN t_move AS M
			ON TP.obj->>'requiredMove' = M.move_name;

INSERT INTO pokemon (pokemon_id, species_num, forme_index, pokemon_name, female_ratio, base_stats, heightm, weightkg, color, can_hatch, can_gigantamax, cannot_dynamax, gen, unreleased_hidden, max_hp)
	SELECT
		obj->>'alias',
		(obj->'num')::smallint,
		PF.forme_index,
		replace(obj->>'name', E'\u2019', ''''),  -- Farfetch’d > Farfetch'd
		CASE
			WHEN obj->>'gender' = 'F' THEN 1
			WHEN obj->>'gender' = 'M' THEN 0
			WHEN obj->>'gender' = 'N' THEN 'NaN'::numeric
			WHEN obj->'gender' IS NULL AND obj->'genderRatio' IS NULL THEN 0.5
			ELSE (obj->'genderRatio'->>'F')::numeric
		END,
		jsonb_populate_record(null::type_stats, obj->'baseStats'),
		(obj->'heightm')::smallint,
		(obj->'weightkg')::smallint,
		(obj->>'color')::enum_color,
		(obj->'canHatch')::boolean,
		M.move_id,
		(obj->'cannotDynamax')::boolean,
		(obj->'gen')::smallint,
		(obj->>'unreleasedHidden')::enum_unreleased,
		(obj->'maxHP')::smallint
	FROM tmp_pokedex TP
		LEFT JOIN pokemon_forme PF
			ON PF.pokemon_name = replace(TP.obj->>'name', E'\u2019', '''')
		LEFT JOIN t_move AS M
			ON TP.obj->>'canGigantamax' = M.move_name
	WHERE lower(obj->>'forme') IS DISTINCT FROM 'gmax';

INSERT INTO item
	SELECT (jsonb_populate_record(null::item, jsonb_object_agg(camel_to_snake_case(k), v) || jsonb_with_renamed_keys || CASE
			WHEN jsonb_typeof(T.obj->'zMove') = 'boolean' THEN jsonb_build_object('is_generic_z_crystal', T.obj->'zMove')
			ELSE jsonb_build_object('species_specific_z_move', MZM.move_id)
		END)).*
	FROM tmp_items T
		LEFT JOIN LATERAL (
			SELECT obj->'alias' AS item_id, jsonb_object_agg(camel_to_snake_case(k), v) AS fling_data
			FROM tmp_items,
				LATERAL jsonb_each(obj->'fling') AS J(k, v)
			GROUP BY obj->'alias'
		) F
			ON F.item_id = T.obj->'alias'
		LEFT JOIN pokemon AS PMS
			ON T.obj->>'megaStone' = PMS.pokemon_name
		LEFT JOIN pokemon AS PME
			ON T.obj->>'megaEvolves' = PME.pokemon_name
		LEFT JOIN t_move AS MZM
			ON T.obj->>'zMove' = MZM.move_name
		LEFT JOIN t_move AS MZF
			ON T.obj->>'zMoveFrom' = MZF.move_name
		LEFT JOIN pokemon AS PFM
			ON T.obj->>'forcedForme' = PFM.pokemon_name
		CROSS JOIN LATERAL jsonb_each(obj - '{alias, name, num, condition, naturalGift, megaStone, megaEvolves, zMove, zMoveFrom, forcedForme, fling}'::text[]) AS J(k, v)
		CROSS JOIN LATERAL jsonb_build_object(
			'item_id', obj->'alias',
			'item_name', obj->'name',
			'item_num', obj->'num',
			'jb_condition', obj->'condition',
			'natural_gift_base_power', obj->'naturalGift'->'basePower',
			'natural_gift_type', obj->'naturalGift'->'type',
			'mega_stone', PMS.pokemon_id,
			'mega_evolves', PME.pokemon_id,
			'z_move_from', MZF.move_id,
			'forced_forme', PFM.pokemon_id,
			'fling', F.fling_data
		) AS jsonb_with_renamed_keys
	GROUP BY jsonb_with_renamed_keys, T.obj, MZM.move_id;

INSERT INTO item_priority
	SELECT (jsonb_populate_record(null::item_priority, json_rec)).*
	FROM (
		SELECT (jsonb_object_agg(camel_to_snake_case(k), v) || jsonb_with_renamed_keys) AS json_rec
		FROM tmp_items,
			LATERAL jsonb_each(
				obj - '{alias, onAllyModifySpAPriority, onAllyModifySpDPriority, onModifySpAPriority, onModifySpDPriority, onSourceModifySpAPriority}'::text[]
			) AS J(k, v),
			LATERAL jsonb_build_object(
				'item_id', obj->'alias',
				'on_ally_modify_spa_priority', obj->'onAllyModifySpAPriority', 
				'on_ally_modify_spd_priority', obj->'onAllyModifySpDPriority', 
				'on_modify_spa_priority', obj->'onModifySpAPriority',     
				'on_modify_spd_priority', obj->'onModifySpDPriority',     
				'on_source_modify_spa_priority', obj->'onSourceModifySpAPriority'
			) AS jsonb_with_renamed_keys
		GROUP BY jsonb_with_renamed_keys
	) AS S
	WHERE NOT jsonb_populate_record(null::item_priority, json_rec - 'item_id') IS NULL;

INSERT INTO item_user (item_id, pokemon_id)
	SELECT obj->>'alias', P.pokemon_id
	FROM tmp_items
		CROSS JOIN LATERAL jsonb_array_elements_text(obj->'itemUser')
		LEFT JOIN pokemon AS P
			ON replace(value, E'\u2019', '''') = P.pokemon_name;

DROP TABLE IF EXISTS tmp_items;


--WITH modifying_cte AS (  -- Lazy workaround to missing items
--	INSERT INTO item (item_id, item_name)
--		SELECT to_id(required_item_name), required_item_name
--		FROM (
--			SELECT DISTINCT COALESCE(TP.obj->>'requiredItem', value) AS required_item_name
--			FROM tmp_pokedex TP
--				LEFT JOIN LATERAL jsonb_array_elements_text(TP.obj->'requiredItems')
--					ON TRUE
--		) S
--		WHERE required_item_name IS NOT NULL
--			AND NOT EXISTS (SELECT 1 FROM item I WHERE S.required_item_name = I.item_name)
--)
INSERT INTO pokemon_forme_required_item (species_num, forme_index, required_item)
	SELECT S.species_num, S.forme_index, I.item_id
	FROM (
		SELECT
			PF.species_num,
			PF.forme_index,
			COALESCE(TP.obj->>'requiredItem', value) AS required_item
		FROM pokemon_forme PF
			LEFT JOIN tmp_pokedex TP
				ON PF.pokemon_name = TP.obj->>'name'
			LEFT JOIN LATERAL jsonb_array_elements_text(TP.obj->'requiredItems')
				ON TRUE
	) S
		INNER JOIN item AS I
			ON S.required_item = I.item_name;

INSERT INTO pokemon_forme_battle_only (species_num, forme_index, battle_only)
	SELECT
		PF.species_num, PF.forme_index, P.pokemon_id
	FROM pokemon_forme PF
		LEFT JOIN tmp_pokedex TP
			ON PF.pokemon_name = replace(TP.obj->>'name', E'\u2019', '''')
		CROSS JOIN LATERAL jsonb_array_elements_text(CASE
			WHEN jsonb_typeof(TP.obj->'battleOnly') = 'array' THEN TP.obj->'battleOnly'
			ELSE jsonb_build_array(TP.obj->'battleOnly')
		END) AS L
		INNER JOIN pokemon AS P
			ON replace(L.value, E'\u2019', '''') = P.pokemon_name;

INSERT INTO pokemon_egg_group (pokemon_id, egg_group)
	SELECT obj->>'alias', value::enum_egg_group
	FROM tmp_pokedex,
		LATERAL jsonb_array_elements_text(obj->'eggGroups')
	WHERE lower(obj->>'forme') IS DISTINCT FROM 'gmax';

INSERT INTO pokemon_type (pokemon_id, is_secondary, type_name)
	SELECT obj->>'alias', (ordinality = 2), value
	FROM tmp_pokedex,
		LATERAL jsonb_array_elements_text(obj->'types') WITH ORDINALITY
	WHERE lower(obj->>'forme') IS DISTINCT FROM 'gmax'
		AND obj->>'alias' <> 'missingno'; -- missingno's type is Bird

INSERT INTO pokemon_ability (pokemon_id, ability_slot, ability_id)
	SELECT obj->>'alias', L.key::enum_ability_slot, A.ability_id
	FROM tmp_pokedex
		CROSS JOIN LATERAL jsonb_each_text(obj->'abilities') AS L
		LEFT JOIN ability AS A
			ON L.value = A.ability_name
	WHERE lower(obj->>'forme') IS DISTINCT FROM 'gmax'
		AND obj->>'alias' <> 'missingno';  -- missingno's ability is an empty string

--WITH modifying_cte AS (  -- Lazy workaround to missing items
--	INSERT INTO item (item_id, item_name)
--		SELECT DISTINCT to_id(obj->>'evoItem'), obj->>'evoItem'
--		FROM tmp_pokedex T
--		WHERE obj->>'evoItem' IS NOT NULL
--			AND NOT EXISTS (SELECT 1 FROM item I WHERE T.obj->>'evoItem' = I.item_name)
--)
INSERT INTO pokemon_evo (pokemon_id, evo_id, evo_level, evo_type, evo_item, evo_move, evo_condition)
	SELECT
		P.pokemon_id,
		obj->>'alias',
		(obj->'evoLevel')::smallint,
		(obj->>'evoType')::enum_evo_type,
		I.item_id,
		M.move_id,
		obj->>'evoCondition'
	FROM tmp_pokedex T
		INNER JOIN pokemon P
			ON T.obj->>'prevo' = P.pokemon_name
		LEFT JOIN item AS I
			ON T.obj->>'evoItem' = I.item_name
		LEFT JOIN t_move AS M
			ON T.obj->>'evoMove' = M.move_name;

DROP TABLE IF EXISTS tmp_pokedex;


-- name: populate_pokedex_text!
-- Populate table pokemon_text.
INSERT INTO pokemon_text (pokemon_id, pokemon_name)
	SELECT obj->>'alias', obj->>'name'
	FROM tmp_pokedex_text
	WHERE obj->>'name' NOT LIKE '%-Gmax';

DROP TABLE IF EXISTS tmp_pokedex_text;


-- name: populate_items_text!
-- Populate table item_text.
--WITH modifying_cte AS (  -- Lazy workaround to missing items
--	INSERT INTO item (item_id, item_name)
--		SELECT obj->>'alias', obj->>'name'
--		FROM tmp_items_text
--		WHERE NOT EXISTS(SELECT 1 FROM item I WHERE obj->>'alias' = I.item_id)
--)
INSERT INTO item_text
	SELECT (jsonb_populate_record(null::item_text, jsonb_object_agg(camel_to_snake_case(k), v) || jsonb_with_renamed_keys)).*
	FROM tmp_items_text,
		LATERAL jsonb_each(obj - '{alias, name, desc, start, end, transform}'::text[]) AS J(k, v),
		LATERAL jsonb_build_object(
			'item_id', obj->'alias',
			'item_name', obj->'name',
			'descr', obj->'desc',
			'start_txt', obj->'start',
			'end_txt', obj->'end',
			'transform_txt',  obj->'transform'
		) AS jsonb_with_renamed_keys
	GROUP BY jsonb_with_renamed_keys;

DROP TABLE IF EXISTS tmp_items_text;


-- name: populate_learnsets#
-- Populate tables pokemon_event, pokemon_event_ability, pokemon_event_move and learnset. Also updates column event_only from table pokemon.
UPDATE pokemon
	SET event_only = (T.obj->'eventOnly')::boolean
	FROM tmp_learnsets T
	WHERE pokemon_id = T.obj->>'alias'
		AND event_only IS DISTINCT FROM (T.obj->'eventOnly')::boolean;

-- A few events refer to pokemon not available in table "pokemon", like gastrodoneast and rockruffdusk.
-- For now I'm just filtering those out while I don't come up with a decent workaround
-- Uncomment the "NOT" to see all currently filtered out.
CREATE TEMPORARY TABLE tmp_events ON COMMIT DROP AS
	SELECT
		obj->>'alias' AS pokemon_id,
		ordinality - 1 AS event_index,
		value AS jb_event
	FROM tmp_learnsets,
		LATERAL jsonb_array_elements(obj->'eventData') WITH ORDINALITY
	WHERE --NOT
		EXISTS(SELECT 1 FROM pokemon P WHERE obj->>'alias' = P.pokemon_id);
	
ANALYZE tmp_events; -- temp tables are not auto-analyzed!

ALTER TABLE tmp_events ADD PRIMARY KEY (pokemon_id, event_index);


INSERT INTO pokemon_event (pokemon_id, event_index, generation, lvl, shiny, gender, nature, ivs, perfect_ivs, is_hidden, max_egg_moves, pokeball)
	SELECT
		pokemon_id,
		event_index,
		(jb_event->'generation')::smallint,
		(jb_event->'level')::smallint,
		(CASE jb_event->>'shiny' WHEN 'true' THEN 'Always' WHEN '1' THEN 'Sometimes' ELSE 'Never' END)::enum_ternary,
		jb_event->>'gender',
		jb_event->>'nature',
		jsonb_populate_record(null::type_stats, jb_event->'ivs'),
		(jb_event->'perfectIVs')::smallint,
		(jb_event->'isHidden')::boolean,
		(jb_event->'maxEggMoves')::smallint,
		jb_event->>'pokeball'
	FROM tmp_events;

INSERT INTO pokemon_event_ability (pokemon_id, event_index, ability_id)
	SELECT
		pokemon_id,
		event_index,
		value
	FROM tmp_events,
		LATERAL jsonb_array_elements_text(jb_event->'abilities');

INSERT INTO pokemon_event_move (pokemon_id, event_index, move_id, move_slot)
	SELECT
		pokemon_id,
		event_index,
		value,
		ordinality - 1
	FROM tmp_events,
		LATERAL jsonb_array_elements_text(jb_event->'moves') WITH ORDINALITY;

INSERT INTO learnset (pokemon_id, move_id, generation, source_id, event_index, lvl)
	SELECT 
		obj->>'alias',
		L1.key,
		SUBSTRING(L2.value FROM '^\d+')::smallint,
		SUBSTRING(L2.value FROM '^\d+([MTLREDSV])')::enum_move_source,
		SUBSTRING(L2.value FROM '^\d+S(\d+)')::smallint,
		SUBSTRING(L2.value FROM '^\d+L(\d+)')::smallint
	FROM tmp_learnsets,
		LATERAL jsonb_each(obj->'learnset') L1,
		LATERAL jsonb_array_elements_text(L1.value) L2
	WHERE SUBSTRING(L2.value FROM '^\d+(.)') = ANY(enum_range(NULL::enum_move_source)::text[])
		AND --NOT
			EXISTS(SELECT 1 FROM pokemon P WHERE obj->>'alias' = P.pokemon_id);

DROP TABLE IF EXISTS tmp_events;
DROP TABLE IF EXISTS tmp_learnsets;



-- name: populate_analyses#
-- Expects all elements in a single jsonb object.
INSERT INTO analysis (pokemon_id, gen, lang, format, html_overview, html_comments, credits)
	SELECT
		CASE L1.value->>'alias' WHEN 'meowstic-m' THEN 'meowstic' ELSE replace(L1.value->>'alias', '-', '') END,
		upper(L1.value->>'gen'),
		L1.value->>'language',
		L2.value->>'format',
		L2.value->>'overview',
		L2.value->>'comments',
		L2.value->'credits'
	FROM tmp_smogon_analyses,
		LATERAL jsonb_array_elements(obj) L1,
		LATERAL jsonb_array_elements(L1.value->'strategies') L2;

CREATE TEMPORARY TABLE tmp_movesets ON COMMIT DROP AS
	SELECT
		A.analysis_id,
		L3.ordinal - 1 AS moveset_index,
		L3.jb_moveset
	FROM tmp_smogon_analyses
		CROSS JOIN LATERAL jsonb_array_elements(obj) L1
		CROSS JOIN LATERAL jsonb_array_elements(L1.value->'strategies') L2
		CROSS JOIN LATERAL jsonb_array_elements(L2.value->'movesets') WITH ORDINALITY L3(jb_moveset, ordinal)
		LEFT JOIN analysis A
			ON A.pokemon_id = CASE L1.value->>'alias' WHEN 'meowstic-m' THEN 'meowstic' ELSE replace(L1.value->>'alias', '-', '') END
			AND (A.gen, A.lang, A.format) = (upper(L1.value->>'gen'), L1.value->>'language', L2.value->>'format');
	
ANALYZE tmp_movesets; -- temp tables are not auto-analyzed!

ALTER TABLE tmp_movesets ADD PRIMARY KEY (analysis_id, moveset_index);

DROP TABLE IF EXISTS tmp_smogon_analyses;


INSERT INTO moveset (analysis_id, moveset_index, moveset_name, pokemon, shiny, gender, lvl, html_description)
	SELECT
		analysis_id,
		moveset_index,
		jb_moveset->>'name',
		CASE jb_moveset->>'pokemon'  -- Is this what they call "test-driven development"?
			WHEN 'Meowstic-M' THEN 'Meowstic'
			WHEN 'Flabebe' THEN E'Flabe\u0301be\u0301'
			WHEN 'Necrozma-Dusk Mane' THEN 'Necrozma-Dusk-Mane'
			WHEN 'Necrozma-Dawn Wings' THEN 'Necrozma-Dawn-Wings'
			ELSE replace(jb_moveset->>'pokemon', '-Gmax', '')
		END,
		(jb_moveset->'shiny')::boolean,
		jb_moveset->>'gender',
		(jb_moveset->'level')::smallint,
		jb_moveset->>'description'
	FROM tmp_movesets;

INSERT INTO moveset_ability (analysis_id, moveset_index, ability_name)
	SELECT
		analysis_id,
		moveset_index,
		value
	FROM tmp_movesets,
		LATERAL jsonb_array_elements_text(jb_moveset->'abilities');

--WITH modifying_cte AS (  -- Lazy workaround to missing items
--	INSERT INTO item (item_id, item_name)
--		SELECT DISTINCT to_id(value), value
--		FROM tmp_movesets,
--			LATERAL jsonb_array_elements_text(jb_moveset->'items')
--		WHERE value <> 'No Item'
--			AND NOT EXISTS(SELECT 1 FROM item I WHERE value = I.item_name)
--)
INSERT INTO moveset_item (analysis_id, moveset_index, item_name)
	SELECT
		analysis_id,
		moveset_index,
		value
	FROM tmp_movesets,
		LATERAL jsonb_array_elements_text(jb_moveset->'items')
	WHERE value <> 'No Item';

INSERT INTO moveset_move (analysis_id, moveset_index, slot, move_name)
	SELECT DISTINCT  -- Distinct because Hidden Power
		analysis_id,
		moveset_index,
		l4.ordinality - 1,
		L5.value->>'move'
	FROM tmp_movesets,
		LATERAL jsonb_array_elements(jb_moveset->'moveslots') WITH ORDINALITY L4,
		LATERAL jsonb_array_elements(L4.value) L5;

INSERT INTO moveset_evconfig (analysis_id, moveset_index, evconfig)
	SELECT
		analysis_id,
		moveset_index,
		jsonb_populate_record(null::type_stats, value)
	FROM tmp_movesets,
		LATERAL jsonb_array_elements(jb_moveset->'evconfigs');

INSERT INTO moveset_ivconfig (analysis_id, moveset_index, ivconfig)
	SELECT
		analysis_id,
		moveset_index,
		jsonb_populate_record(null::type_stats, value)
	FROM tmp_movesets,
		LATERAL jsonb_array_elements(jb_moveset->'ivconfigs');

INSERT INTO moveset_nature (analysis_id, moveset_index, nature_name)
	SELECT
		analysis_id,
		moveset_index,
		value
	FROM tmp_movesets,
		LATERAL jsonb_array_elements_text(jb_moveset->'natures');
		
DROP TABLE IF EXISTS tmp_movesets;
