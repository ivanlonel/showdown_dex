import collections
import itertools
import difflib
import logging
import hjson  # https://github.com/hjson/hjson-py
import json
import re
from shortest_common_supersequence import shortest_common_supersequence, longest_common_subsequence, reduce_generator


def standardize(dicts):
    list_of_dicts = list(dicts)

    all_keys = list(reduce_generator(shortest_common_supersequence, (d.keys() for d in list_of_dicts)))

    logging.debug(all_keys)

    template = {k: None for k in all_keys}

    # Yield each dictionary with the missing keys added with None as value
    for dic in list_of_dicts:
        yield {**template, **dic}


# I don't feel like going through the hassle of creating an actual typescript parser
def extract_json_from_ts(ts_str):
    trimmed_str = ts_str.split('} = ', 1)[1].rsplit('}', 1)[0] + '}'
    functionless_str = re.sub(r'^(\s+)[^\d\W]\w*\s*\(.*?\)\s*\{.*?\n\1\},?', '',
                              trimmed_str, flags=re.DOTALL|re.MULTILINE|re.UNICODE
                             )
    return hjson.loads(functionless_str)


if __name__ == '__main__':
    logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(name)s - %(message)s')

    for filename in ('conditions', 'abilities', 'items', 'moves', 'typechart', 'pokedex', 'learnsets'):
        with open(f'./pokemon-showdown/data/{filename}.ts', 'r') as f:
            json_dict = extract_json_from_ts(f.read())

        # Generate list of dicts from dict of dicts
        dicts = [{'slug': k, **v} for k, v in json_dict.items()]

        logging.debug(list(reduce_generator(longest_common_subsequence, (d.keys() for d in dicts))))

        # TO-DO NEXT: Actually do something with the data instead of pretty-printing it to files
        with open(f'./output/{filename}.json', 'w', encoding='utf-8') as f:
            json.dump(list(standardize(dicts)), f, ensure_ascii=False, indent='\t')