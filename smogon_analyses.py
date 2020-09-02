import sys
import ujson
import regex
import logging
import asyncio
import aiohttp
import aiofiles
import tenacity
import itertools


@tenacity.retry(
                retry = tenacity.retry_if_exception_type(aiohttp.ClientError)
                      | tenacity.retry_if_exception_type(asyncio.TimeoutError),
                wait = tenacity.wait_random_exponential(multiplier=1.875, max=60),
                stop = tenacity.stop_after_attempt(7),
                reraise = True,
                before_sleep = tenacity.before_sleep.before_sleep_log(logging.getLogger(), logging.DEBUG, exc_info=False)
               )
async def fetch(session, url, json=None):
	async with session.post(url, json=json, raise_for_status=True) as response:
		return await response.json()

async def bound_fetch(session, semaphore, url, json=None):
	async with semaphore:
		return {'request': json, 'response': await fetch(session, url, json=json)}

def to_alias(name):
	return regex.sub(r'[^a-z0-9\-]+', '', name.lower().replace(' ', '-'))

async def main():
	URL = 'https://www.smogon.com/dex/_rpc'
	LANGUAGE = 'en'
	MAX_SIM_CONNS = 64

	async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=60)) as session:
		json_gens = await fetch(session, f'{URL}/dump-gens')

		gens = [gen['shorthand'] for gen in json_gens]

		logging.debug(f'Gens: {gens}')

		sem = asyncio.Semaphore(MAX_SIM_CONNS)

		tasks_basics = (asyncio.create_task(bound_fetch(session, sem, f'{URL}/dump-basics', json={'gen': gen.lower()})) for gen in gens)
		json_basics = [{**item['request'], **item['response']} for item in await asyncio.gather(*tasks_basics)]

		async with aiofiles.open(f'output/smogon_basics.json', 'w', newline='', encoding='utf-8') as fd:
			await fd.write(ujson.dumps(json_basics, ensure_ascii=False, indent='\t'))

		tasks_pokemon = (asyncio.create_task(bound_fetch(session, sem, f'{URL}/dump-pokemon', json={'gen': gen_info['gen'], 'language': LANGUAGE, 'alias': to_alias(pokemon['name'])})) for gen_info in json_basics for pokemon in gen_info['pokemon'])
		json_pokemon = [{**item['request'], **item['response']} for item in await asyncio.gather(*tasks_pokemon) if item['response'] is not None]

		# For each analysis in json_pokemon, look up in which other languages there are analyses for that pokémon/gen and fetch them as well.
		tasks_multilang = (asyncio.create_task(bound_fetch(session, sem, f'{URL}/dump-pokemon', json={'gen': analysis['gen'], 'language': lang, 'alias': analysis['alias']})) for analysis in json_pokemon for lang in analysis['languages'] if lang != LANGUAGE)
		json_multilang = [{**item['request'], **item['response']} for item in await asyncio.gather(*tasks_multilang) if item['response'] is not None]

	analyses = list(itertools.chain(json_pokemon, json_multilang))

	async with aiofiles.open(f'output/smogon_analyses.json', 'w', newline='', encoding='utf-8') as fd:
		await fd.write(ujson.dumps(analyses, ensure_ascii=False, indent='\t'))

	logging.debug(f'Analyses downloaded: {len(analyses)}')



if __name__ == '__main__':
	logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(name)s - %(message)s')

	try:
		import uvloop  # Unavailable on Windows, optional on Unix.
	except ModuleNotFoundError:
		# aiohttp version 3.6.2 raises RuntimeError('Event loop is closed') at the end on Windows if using ProactorEventLoop (which is the default on Windows in Python 3.8+).
		if sys.platform.startswith('win') and sys.version_info[:2] >= (3, 8):
			# Force use of SelectorEventLoop
			asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
	else:
		asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())

	asyncio.run(main())  # Python 3.7+ only. Use code below for 3.6-

#	loop = asyncio.get_event_loop()
#	loop.run_until_complete(main())
#
#	# Zero-sleep to allow underlying connections to close.
#	# Will eventually become obsolete when the asyncio internals are changed
#	# so that aiohttp itself can wait on the underlying connection to close.
#	# Please follow issue #1925 for the progress on this:
#	# https://github.com/aio-libs/aiohttp/issues/1925
#	loop.run_until_complete(asyncio.sleep(0))
#
#	loop.close()
