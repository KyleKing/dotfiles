#!/usr/bin/env python3
"""Run a command under one of SLOTS machine-wide locks; Docker test runs also take a single Docker lock.

Hook typecheckers (cold tsc ~3.5GB, pyright ~3GB), Docker test runs, and local tests from
parallel checkouts queue instead of exhausting memory. Exits with the command's status.
"""

import contextlib
import fcntl
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path

SLOTS = 1
# A hung command would otherwise hold the slot for every checkout; HEAVY_TIMEOUT_S raises it for a known-long run.
TIMEOUT_S = int(os.environ.get('HEAVY_TIMEOUT_S', '1800'))
# The per-user temp dir, not $TMPDIR, so a sandbox that rewrites TMPDIR still shares the locks.
LOCK_DIR = Path(subprocess.run(['getconf', 'DARWIN_USER_TEMP_DIR'], capture_output=True, text=True, check=True).stdout.strip())
# Slot 0 keeps the single-lock path, so holders started under the old lockf wrapper still count.
SLOT_PATHS = [LOCK_DIR / 'pr-pass-heavy.lock', *(LOCK_DIR / f'pr-pass-heavy.{i}.lock' for i in range(1, SLOTS))]
DOCKER_PATH = LOCK_DIR / 'pr-pass-heavy.docker.lock'
DOCKER_CMD = re.compile(r'\bmake\b.*\btest-|\bdocker\b')
# The Storybook vitest browser server binds a fixed port, so two checkouts cannot run it at once.
STORYBOOK_PATH = LOCK_DIR / 'pr-pass-heavy.storybook.lock'
STORYBOOK_CMD = re.compile(r'--project[= ]storybook|\bstorybook\b')


def try_lock(path: Path) -> int | None:
    fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        return None
    os.ftruncate(fd, 0)
    os.write(fd, str(os.getpid()).encode())
    return fd


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def waiters_ahead(queue: Path, ticket: Path) -> int:
    ahead = 0
    for other in sorted(queue.iterdir()):
        if other == ticket:
            break
        if alive(int(other.name.rsplit('-', 1)[1])):
            ahead += 1
        else:
            other.unlink(missing_ok=True)
    return ahead


def lock_any(paths: list[Path]) -> int:
    # flock has no queue order, so a back-to-back caller would retake the lock before older waiters poll.
    queue = paths[0].with_suffix('.queue')
    queue.mkdir(exist_ok=True)
    ticket = queue / f'{time.time_ns():020d}-{os.getpid()}'
    ticket.touch()
    try:
        while True:
            if waiters_ahead(queue, ticket) < len(paths):
                for path in paths:
                    if (fd := try_lock(path)) is not None:
                        return fd
            time.sleep(1)
    finally:
        ticket.unlink(missing_ok=True)


def main(argv: list[str]) -> int:
    if not argv:
        sys.exit('usage: heavy.sh <command> [args...]')
    if DOCKER_CMD.search(' '.join(argv)):
        lock_any([DOCKER_PATH])
    if STORYBOOK_CMD.search(' '.join(argv)):
        lock_any([STORYBOOK_PATH])
    lock_any(SLOT_PATHS)
    # An editor waiting on input would hold a slot and stall every other checkout.
    proc = subprocess.Popen(argv, env={**os.environ, 'GIT_EDITOR': 'true'}, start_new_session=True)
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, lambda s, _f: signal_group(proc, s))
    try:
        rc = proc.wait(timeout=TIMEOUT_S)
    except subprocess.TimeoutExpired:
        print(f'heavy.sh: killed after {TIMEOUT_S}s holding the heavy-job slot: {" ".join(argv)}', file=sys.stderr)
        signal_group(proc, signal.SIGTERM)
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            signal_group(proc, signal.SIGKILL)
            proc.wait()
        return 124
    return 128 - rc if rc < 0 else rc


def signal_group(proc: subprocess.Popen[bytes], sig: int) -> None:
    with contextlib.suppress(ProcessLookupError):
        os.killpg(proc.pid, sig)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
