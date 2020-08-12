import itertools
import hjson
import json

def standardize(json_dict):
    # Generate list of dicts from dict of dicts
    dicts = [{**v, 'slug': k} for k, v in json_dict.items()]

    # Obtain a set containing every key existing amongst all the dictionaries in the list
    all_keys = set(itertools.chain.from_iterable(dicts))

    # Yield each dictionary with the missing keys added with None as value
    for dic in dicts:
        #dic.update((k, None) for k in all_keys if k not in dic)
        #dic.update((k, None) for k in all_keys - dic.viewkeys())
        #yield dic
        #yield {**dic, **{k: None for k in all_keys if k not in dic}}
        #yield {**dic, **{k: None for k in all_keys - dic.viewkeys()}}
        yield {**dic, **dict.fromkeys(all_keys - dic.keys())}


# I'm not willing to go through the hassle of creating an actual parser
def extract_json_from_ts(ts_string):
    return hjson.loads(ts_string.split('} = ', 1)[1].rsplit('}', 1)[0] + '}')


if __name__ == '__main__':
    with open('./pokemon-showdown/data/pokedex.ts', 'r') as f:
        json_dict = extract_json_from_ts(f.read())

    print(json.dumps(list(standardize(json_dict)), indent='\t'))