import difflib
import itertools
from typing import Any, Generator, Iterable, Iterator

def longest_common_subsequence(seq1: Iterable[Any], seq2: Iterable[Any]) -> Iterator[Any]:
    a = list(seq1)
    b = list(seq2)
    lcs = (a[block.a:(block.a + block.size)] for block in difflib.SequenceMatcher(None, a, b).get_matching_blocks())
    yield from itertools.chain.from_iterable(lcs)


def shortest_common_supersequence(seq1: Iterable[Any], seq2: Iterable[Any]) -> Iterator[Any]:
    a = list(seq1)
    b = list(seq2)

    X = iter(a)
    Y = iter(b)
    LCS = longest_common_subsequence(a, b)

    x = next(X)
    y = next(Y)
    lcs = next(LCS)

    # Consume lcs
    while True:
        if x == y == lcs:  # Part of the LCS, so consume from all sequences
            yield lcs
            try:
                lcs = next(LCS)
            except StopIteration:
                break
            x = next(X)
            y = next(Y)
        elif x == lcs:
            yield y
            y = next(Y)
        else:
            yield x
            x = next(X)

    # yield remaining elements
    yield from X
    yield from Y


# functools.reduce may exceed maximum recursion depth when function is a generator, so let's force iteration
def reduce_generator(generator_func: Generator[Any, None, None], iterable: Iterable[Any]) -> list:
    iterator = iter(iterable)
    accumulated = next(iterator)
    for element in iterator:
        accumulated = list(generator_func(accumulated, element))
    return accumulated