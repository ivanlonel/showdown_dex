import sys
import logging
import pathlib
import contextlib
import aiofiles
import asyncio
import asyncpg
import aiosql  # https://github.com/nackjicholson/aiosql
import orjson
import regex
from extract_json_from_ts import dict_of_dicts_2_iter_of_dicts, extract_json_from_ts

def camel_to_snake_case(name):
	return regex.sub('((?<=[a-z0-9])[A-Z]|(?!^)(?<!_)[A-Z](?=[a-z]))', r'_\1', name).lower()

async def init_tmp_table(conn, file_path, each_file_line_is_a_json_object=False):
	tmp = f'tmp_{file_path.stem}'

	if file_path.parts[-2] == 'text':
		tmp += '_text'

	await conn.execute(f'CREATE TEMPORARY TABLE {tmp} (obj jsonb) ON COMMIT DROP')

	if each_file_line_is_a_json_object:
		result = await conn.copy_to_table(tmp, source=file_path)
	else:
		if file_path.suffix == '.ts':
			async with aiofiles.open(file_path, 'r', newline='', encoding='utf-8') as fd:
				json_payload = await fd.read()
			json_objects = dict_of_dicts_2_iter_of_dicts(extract_json_from_ts(json_payload), 'alias')
		else:  # Assuming a .json already in the right format
			async with aiofiles.open(file_path, 'rb') as fd:
				json_payload = await fd.read()
			json_objects = orjson.loads(json_payload)
		result = await conn.copy_records_to_table(tmp, records=((obj,) for obj in json_objects))

	logging.debug(f'{file_path.stem}: {result}')
	return result

async def main():
	path = pathlib.Path('.')
	queries = aiosql.from_path(path/'sql', 'asyncpg')
	#logging.debug(queries.populate_pokedex.sql)

	conn = await asyncpg.connect('postgresql://dex:1234@localhost:5432/showdown_dex')

	try:
		await conn.set_type_codec(
			'jsonb',  # https://github.com/MagicStack/asyncpg/issues/140#issuecomment-301477123
			encoder=lambda json_obj: b'\x01' + orjson.dumps(json_obj),
			decoder=lambda byte_arr: orjson.loads(byte_arr[1:]),
			schema='pg_catalog',
			format='binary'
		)

		async with conn.transaction():
			await queries.create_schema(conn)

		async with conn.transaction():
			try:
				await init_tmp_table(conn, path/'json'/'smogon_gens.json', True)
			except FileNotFoundError:
				logging.error('Json file not found. Make sure to run smogon_analyses.py first to create files smogon_gens.json and smogon_analyses.json.')
				raise
			await queries.populate_generation(conn)

			await init_tmp_table(conn, path/'pokemon-showdown'/'data'/'typechart.ts')
			await queries.populate_types(conn)

			await init_tmp_table(conn, path/'pokemon-showdown'/'data'/'abilities.ts')
			await queries.populate_abilities(conn)

			await init_tmp_table(conn, path/'pokemon-showdown'/'data'/'text'/'abilities.ts')
			await queries.populate_abilities_text(conn)

			await init_tmp_table(conn, path/'pokemon-showdown'/'data'/'moves.ts')
			await queries.populate_moves(conn)

			await init_tmp_table(conn, path/'pokemon-showdown'/'data'/'text'/'moves.ts')
			await queries.populate_moves_text(conn)

			await init_tmp_table(conn, path/'pokemon-showdown'/'data'/'pokedex.ts')
			await init_tmp_table(conn, path/'pokemon-showdown'/'data'/'items.ts')
			await queries.populate_pokedex(conn)

			await init_tmp_table(conn, path/'pokemon-showdown'/'data'/'text'/'pokedex.ts')
			await queries.populate_pokedex_text(conn)

			await init_tmp_table(conn, path/'pokemon-showdown'/'data'/'text'/'items.ts')
			await queries.populate_items_text(conn)

			await init_tmp_table(conn, path/'pokemon-showdown'/'data'/'learnsets.ts')
			await queries.populate_learnsets(conn)

		async with conn.transaction():
			try:
				await init_tmp_table(conn, path/'json'/'smogon_analyses.json', True)
			except FileNotFoundError:
				logging.error('Json file not found. Make sure to run smogon_analyses.py first to create files smogon_gens.json and smogon_analyses.json.')
				raise
			await queries.populate_analyses(conn)
	finally:
		await conn.close()


if __name__ == '__main__':
	logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(name)s - %(message)s')

	with contextlib.suppress(ModuleNotFoundError):
		import uvloop  # Unavailable on Windows, optional on Unix.
		asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())

	asyncio.run(main())