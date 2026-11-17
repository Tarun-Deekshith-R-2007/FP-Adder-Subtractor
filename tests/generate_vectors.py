"""Exact integer oracle: all finite binary32 values are multiples of 2**-149."""
import argparse
import random
from pathlib import Path


def reference(a, b, sub):
    b ^= sub << 31
    ea, eb = (a >> 23) & 255, (b >> 23) & 255
    fa, fb = a & 0x7fffff, b & 0x7fffff
    sa, sb = a >> 31, b >> 31
    if (ea == 255 and fa) or (eb == 255 and fb):
        return 0x7fc00000
    if ea == 255 and eb == 255 and sa != sb:
        return 0x7fc00000
    if ea == 255:
        return (sa << 31) | 0x7f800000
    if eb == 255:
        return (sb << 31) | 0x7f800000

    def units(e, f, s):
        m = ((1 << 23) | f) << (e - 1) if e else f
        return -m if s else m

    n = units(ea, fa, sa) + units(eb, fb, sb)
    if n == 0:
        return (sa & sb) << 31
    sign = int(n < 0) << 31
    n = abs(n)
    if n < (1 << 23):
        return sign | n
    shift = max(0, n.bit_length() - 24)
    q, rem = divmod(n, 1 << shift)
    if shift and (rem > (1 << (shift - 1)) or
                  (rem == (1 << (shift - 1)) and q & 1)):
        q += 1
    if q == 1 << 24:
        q >>= 1
        shift += 1
    exponent = shift + 1
    if exponent >= 255:
        return sign | 0x7f800000
    return sign | (exponent << 23) | (q & 0x7fffff)


def cases(count, seed):
    edge = [0, 1, 2, 0x3fffff, 0x7ffffe, 0x7fffff, 0x800000,
            0x800001, 0xffffff, 0x1000000, 0x33800000, 0x33000000,
            0x3f000000, 0x3f7fffff, 0x3f800000, 0x3f800001,
            0x40000000, 0x7f000000, 0x7f7ffffe, 0x7f7fffff,
            0x7f800000, 0x7f800001, 0x7fc00000, 0x7fffffff]
    edge += [x | 0x80000000 for x in edge]
    for a in edge:
        for b in edge:
            for sub in (0, 1):
                yield a, b, sub
    # Halfway ties for both retained-LSB parities, across the exponent range.
    for e in range(25, 255):
        for lsb in (0, 1):
            for sign in (0, 0x80000000):
                a = sign | (e << 23) | lsb
                b = (e - 24) << 23
                for sub in (0, 1):
                    yield a, b, sub
    rng = random.Random(seed)
    for i in range(count):
        a, b = rng.getrandbits(32), rng.getrandbits(32)
        mode = i % 5
        if mode == 0:  # subnormal pairs
            a &= 0x807fffff
            b &= 0x807fffff
        elif mode == 1:  # cancellation and near cancellation
            b = (a ^ 0x80000000) + rng.choice((-1, 0, 1))
            b &= 0xffffffff
        elif mode == 2:  # equal exponent, arbitrary fractions and signs
            b = (b & 0x807fffff) | (a & 0x7f800000)
        yield a, b, rng.randrange(2)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--count', type=int, default=100000)
    p.add_argument('--seed', type=int, default=20261117)
    p.add_argument('--output', default='build/vectors.txt')
    args = p.parse_args()
    path = Path(args.output)
    path.parent.mkdir(parents=True, exist_ok=True)
    total = 0
    with path.open('w') as f:
        for a, b, sub in cases(args.count, args.seed):
            f.write(f'{a:08x} {b:08x} {sub:x} {reference(a,b,sub):08x}\n')
            total += 1
    print(f'Generated {total} exact-reference vectors (seed {args.seed})')
