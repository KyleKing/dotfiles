#!/usr/bin/env python3
"""Put the pr-pass validated line on the first line of a PR description, replacing any earlier one.

The line is an HTML comment: `<!-- pr-pass:validated <UTC timestamp> <note> -->`.
Everything else in the body is left byte-for-byte. Run from inside a checkout of the PR's repo.
"""

import argparse
import re
import sys
from datetime import UTC, datetime

from blockers import body_of, write

LINE = re.compile(r'\A<!-- pr-pass:validated [^\n]*?-->\n*')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('pr', type=int)
    parser.add_argument('note', help='at most two sentences a future session needs')
    args = parser.parse_args()

    note = ' '.join(args.note.split())
    if '-->' in note or len(re.findall(r'[.!?](\s|$)', note)) > 2:
        sys.exit('note must be at most two sentences and hold no "-->"')
    stamp = datetime.now(UTC).strftime('%Y-%m-%dT%H:%MZ')
    rest = LINE.sub('', body_of(args.pr), count=1)
    write(args.pr, f'<!-- pr-pass:validated {stamp} {note} -->\n{rest}')


if __name__ == '__main__':
    main()
