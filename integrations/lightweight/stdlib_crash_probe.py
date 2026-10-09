"""Bounded standard-library-only probe; no GameAI imports or state changes."""
import copy
import sys
import time


def main():
    source = {'agents': [
        {'pose': [1., 2., 3.], 'history': [{'a': i, 'b': [1, 2, 3]} for i in range(20)]}
        for _ in range(3)
    ]}
    print(sys.version, flush=True)
    start = time.monotonic()
    count = 0
    while time.monotonic() - start < 30:
        result = copy.deepcopy(source)
        if result != source:
            raise RuntimeError('deepcopy mismatch')
        count += 1
    print({'copies': count, 'seconds': time.monotonic() - start}, flush=True)


if __name__ == '__main__':
    main()
