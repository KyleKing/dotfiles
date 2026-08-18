---
name: python-async
description: Async Python conventions and footguns — asyncio.TaskGroup over gather, event-loop-bound primitives, offloading blocking work to threads or processes, cancellation across the thread boundary, and dedicated executors. Use when writing or reviewing async def, await, asyncio.to_thread, run_in_executor, create_task, async generators, or when diagnosing a stalled event loop, a "bound to a different event loop" error, or latency that only appears under load.
---

# Python async

Every rule here has a failure it was written for.
Where a number appears it was measured, in the beacon repo
(`docs/docs/adr/0011-async-aws-io-and-blocking-work.md` there) or in the platform
incident
it cites.
Those paths resolve only inside beacon.

## Concurrency

Use `asyncio.TaskGroup`, never `asyncio.gather`.
`gather` does not cancel siblings on failure — they keep running on their sessions
during teardown.
`TaskGroup` cancels them.

Concurrent branches must not share one session or connection object.
Sessions are not safe for concurrent use.

Fire-and-forget needs a wrapper that holds a strong reference, enforces a timeout, and
logs uncaught exceptions.
Use a raw `asyncio.create_task` only when the result is awaited or the caller manages
cancellation.

Close async generators backed by paginators.
Abandoning the generator mid-page leaves the HTTP response open until the interpreter
finalizes it.

## Event-loop-bound primitives

Never declare an `asyncio.Semaphore`, `Lock`, or `Event` at module level.
They bind to the first event loop that touches them.
Build them inside the running loop.

The failure is not subtle in production: a process hosting more than one loop raises
`RuntimeError: ... is bound to a different event loop`, and the handler then fails
continuously until the process restarts (platform DEV-1234).

A per-key map of locks (one lock per entity id) has the same trap — the cached
`asyncio.Lock()` objects are loop-bound.
Key the cache by `(name, id(running_loop))`, or rebuild it per loop.

## When to be async at all

Async-first for new I/O code. Sync stays sync for pure helpers: utility functions, pure
transforms, and anything with no I/O gain nothing from `async def`, and the wrapper adds
noise.

An `async def` with no `await` is a bug — it blocks the event loop.
Make the body actually async or drop the `async`.
The exceptions are an async generator and an adapter conforming to an awaitable
signature.

Do not fake async. `async def handler(...): await asyncio.to_thread(sync_body, ...)`
claims event-loop semantics the handler does not have, blocks the framework heartbeat
loop, and hides the design seam.
Equally, do not wrap a sync query layer in `async def` — a thread is still required
underneath, and hiding the hop makes it easy to lose.

Never call `asyncio.run(...)` inside a sync handler.
Spawning a fresh event loop per task call is wasteful and breaks the moment a shared
`TaskGroup` is needed; `asyncio.run` inside a running loop raises outright.

## Offloading blocking work

`asyncio.to_thread` has real cost — a thread hop, scheduling overhead, and a new OS
thread or pool contention.
Reserve it for sync HTTP libraries, CPU-bound math, file I/O, and third-party SDKs with
no async path.

Do not use asyncio's default executor. It is shared with every other `to_thread` caller
and sized `min(32, cpu_count + 4)`.
Own a small dedicated pool so its width is chosen rather than inherited from the CPU
count.
Measured: eight concurrent DuckDB queries through `asyncio.to_thread` stalled the loop
for roughly 90ms, versus 1-2ms for the same queries through a small dedicated pool.

Measure before assuming a thread is a real offload.
Four threads of DuckDB queries scaled 3.09x; four threads of pure-Python CPU work scaled
1.07x.
A process pool is only warranted when the hot work is pure Python.

GIL-holding libraries (fitz/PyMuPDF) need `ProcessPoolExecutor` via `run_in_executor`,
under two hard constraints: the pool must be module-level, one per process, and the
callable must be a top-level function rather than a closure, because
`ProcessPoolExecutor` pickles its arguments and closures are not picklable.

## Cancellation

`asyncio.CancelledError` is raised in the async task but does not propagate into a
thread spawned by `asyncio.to_thread` — that thread keeps running until it finishes.
Bridge it with a `threading.Event` the sync worker polls at safe exit points, set in
`except asyncio.CancelledError:` before re-raising.

Always re-raise `CancelledError`. Never swallow it.

A custom cancellation exception must derive from something `except Exception` will not
eat.
`concurrent.futures.CancelledError` derives from `Exception` rather than
`BaseException`, so any `except Exception` between the bridge and the caller quietly
absorbs a cancellation.

Cancellation must raise, not merely end the iterator.
A bridge that ended its iterator early would let `write` finish normally and register a
truncated Parquet file as a complete cache entry, indistinguishable from a real one on
the next read.

## Reviewing and testing

The review-time tell is a blocking call inline in an `async def`.
It looks fine in a single-request test and only shows up as latency under load.

These invariants are greppable, so guard them in tests rather than in review (pattern:
`tests/test_async_invariants.py` in the beacon repo, referenced from its `AGENTS.md`):
no thread workers, no `asyncio.gather`, no module-level primitives, no borrowing the
default executor.

Assert concurrency with a barrier that times out, not with a wall-clock threshold, so a
serialized regression fails with a clear message instead of flaking.
Confirm a new guard actually fails when its invariant is broken.
