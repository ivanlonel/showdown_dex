import itertools
import logging
import hjson  # https://github.com/hjson/hjson-py
import json
import re

def standardize(json_dict):
    # Generate list of dicts from dict of dicts
    dicts = [{'slug': k, **v} for k, v in json_dict.items()]

    # Obtain a set containing every key existing amongst all the dictionaries in the list
    all_keys = set(itertools.chain.from_iterable(dicts))

    # Yield each dictionary with the missing keys added with None as value
    for dic in dicts:  # TO-DO: Benchmark to see which is faster
        #dic.update((k, None) for k in all_keys if k not in dic)
        #dic.update((k, None) for k in all_keys - dic.viewkeys())
        #yield dic
        #yield {**dic, **{k: None for k in all_keys if k not in dic}}
        #yield {**dic, **{k: None for k in all_keys - dic.viewkeys()}}
        yield {**dic, **dict.fromkeys(all_keys - dic.keys())}


# I don't feel like going through the hassle of creating an actual typescript parser
def extract_json_from_ts(ts_str):
    trimmed_str = ts_str.split('} = ', 1)[1].rsplit('}', 1)[0] + '}'
    functionless_str = re.sub(r'^(\s+)[^\d\W]\w*\s*\(.*?\)\s*\{.*?\n\1\},?', '',
                              trimmed_str, flags=re.DOTALL|re.MULTILINE|re.UNICODE
                             )
    return hjson.loads(functionless_str)


if __name__ == '__main__':
    logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(name)s - %(message)s')

    for filename in ('abilities', 'items', 'moves', 'typechart', 'pokedex', 'learnsets'):
        with open(f'./pokemon-showdown/data/{filename}.ts', 'r') as f:
            json_dict = extract_json_from_ts(f.read())

        # TO-DO NEXT: Actually do something with the data instead of pretty-printing it to files
        with open(f'./output/{filename}.json', 'w', encoding='utf-8') as f:
            json.dump(list(standardize(json_dict)), f, ensure_ascii=False, indent='\t')