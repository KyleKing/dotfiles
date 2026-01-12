---
name: hatchet-skill
description: Guide development with Hatchet, an orchestration platform for durable workflows, background tasks, and AI agent pipelines in Python/TypeScript/Go.
---

# Hatchet Skill

Use when implementing or debugging workflows, tasks, or workers with the Hatchet SDK. Hatchet provides sub-25ms task dispatch, durable execution with PostgreSQL persistence, and automatic failure recovery.

## Core concepts

- **Workflow**: Created via `hatchet.workflow()` function, containing one or more tasks
- **Task**: A function decorated with `@workflow.task()` or `@hatchet.durable_task()`
- **Worker**: A process that registers workflows and executes tasks
- **DAG**: Tasks define dependencies via `parents=[task_func]` parameter

## Workflow definition (V1 SDK)

```python
from datetime import timedelta

from hatchet_sdk import Context, EmptyModel, Hatchet
from pydantic import BaseModel

hatchet = Hatchet()

class ProcessInput(BaseModel):
    data: str

# Create workflow object (not a class decorator)
ProcessWorkflow = hatchet.workflow(
    name="process-workflow",
    input_validator=ProcessInput,
)

@ProcessWorkflow.task(execution_timeout=timedelta(seconds=30))
async def extract(input: ProcessInput, ctx: Context) -> dict[str, str]:
    ctx.log(f"Extracting: {input.data}")
    return {"extracted": input.data.upper()}

@ProcessWorkflow.task(parents=[extract])
async def transform(input: ProcessInput, ctx: Context) -> dict[str, bool]:
    extract_result = ctx.task_output(extract)  # Function reference, not string
    return {"transformed": True, "data": extract_result["extracted"]}
```

### Workflow options

| Parameter | Purpose |
|-----------|---------|
| `name` | Workflow identifier (kebab-case recommended) |
| `input_validator` | Pydantic model for input validation |
| `on_events` | List of event triggers (e.g., `["vendor:created"]`) |
| `on_crons` | List of cron expressions (e.g., `["0 5 * * *"]`) |
| `concurrency` | Max concurrent runs (int or expression) |
| `default_priority` | Scheduling priority (higher = sooner) |

## Task configuration

```python
from datetime import timedelta

@workflow.task(
    retries=3,
    backoff_factor=2.0,
    backoff_max_seconds=300,
    execution_timeout=timedelta(seconds=120),
    concurrency=5,
)
async def process(input: ProcessInput, ctx: Context) -> dict[str, str]:
    return {"status": "done"}
```

### Standard vs durable tasks

| Type | Decorator | Use case |
|------|-----------|----------|
| Standard | `@workflow.task()` | Simple, stateless operations |
| Durable | `@hatchet.durable_task()` | Long-running, fault-tolerant with checkpointing |

Durable tasks receive `DurableContext` for state persistence across failures.

## Worker setup

```python
from hatchet_sdk import Hatchet

hatchet = Hatchet()

def main() -> None:
    worker = hatchet.worker(
        name="my-worker",
        slots=50,           # Concurrent standard tasks
        durable_slots=10,   # Concurrent durable tasks
        labels={"service": "workers"},
        workflows=[ProcessWorkflow, OtherWorkflow],
    )
    worker.start()
```

## Triggering workflows

```python
import asyncio

# Async execution (preferred)
result = await ProcessWorkflow.aio_run(ProcessInput(data="hello"))

# Sync execution
result = ProcessWorkflow.run(ProcessInput(data="hello"))

# Event-based (workflow must have on_events configured)
hatchet.event.push("vendor:created", {"vendor_id": "v_123", "org_id": "org_456"})
```

## Fan-out pattern

```python
from hatchet_sdk import Context, TriggerWorkflowOptions

ChildWorkflow = hatchet.workflow(name="child", input_validator=ChildInput)

@ChildWorkflow.task()
async def process_item(input: ChildInput, ctx: Context) -> dict[str, str]:
    return {"item_id": input.item_id, "processed": True}

ParentWorkflow = hatchet.workflow(name="parent", input_validator=ParentInput)

@ParentWorkflow.task()
async def spawn_children(input: ParentInput, ctx: Context) -> dict[str, int]:
    bulk_runs = [
        ChildWorkflow.create_bulk_run_item(
            ChildInput(item_id=f"item_{i}"),
            options=TriggerWorkflowOptions(key=f"child-{i}"),
        )
        for i in range(input.count)
    ]

    # Process in batches of 1000 (API limit)
    results = []
    for i in range(0, len(bulk_runs), 1000):
        batch_results = await ChildWorkflow.aio_run_many(bulk_runs[i:i+1000])
        results.extend(batch_results)

    return {"spawned": len(results)}
```

## Cron scheduling

```python
from hatchet_sdk import Context, EmptyModel

# Use EmptyModel when no input is needed
DailyWorkflow = hatchet.workflow(
    name="daily-job",
    on_crons=["0 5 * * *"],  # Daily at 5 AM UTC
    input_validator=EmptyModel,
)

@DailyWorkflow.task()
async def run_daily(input: EmptyModel, ctx: Context) -> dict[str, str]:
    return {"status": "completed"}
```

## Context methods

| Method | Purpose |
|--------|---------|
| `ctx.log(msg)` | Log message to Hatchet dashboard |
| `ctx.task_output(task_func)` | Get output from parent task |
| `ctx.retry_count()` | Current retry attempt (0-indexed) |
| `ctx.workflow_run_id()` | Unique ID for this workflow run |

## Concurrency strategies

| Strategy | Behavior |
|----------|----------|
| `GROUP_ROUND_ROBIN` | Fair distribution across groups; queues when full |
| `CANCEL_IN_PROGRESS` | Cancels running tasks to prioritize new ones |
| `CANCEL_NEWEST` | Rejects new work; lets in-progress complete |

## Debugging checklist

1. Verify worker is running and registered with control plane
2. Check workflow name matches between definition and trigger
3. Confirm input matches expected Pydantic schema
4. Review task logs in Hatchet dashboard
5. Check for timeout exceeded (default: 60s execution, 5min schedule)
6. Verify `parents=[task_func]` uses function references, not strings

## Self-hosting

Requires PostgreSQL (state), optional RabbitMQ (messaging). Options:
- **Hatchet Lite**: Single image for dev/test
- **Docker Compose**: Multi-container production setup
- **Helm Charts**: Kubernetes deployment

## Safeguards

- Do not suggest removing retry logic without confirming idempotency
- Prefer durable tasks for operations with external side effects
- Validate timeout values against expected execution time
- Flag missing error handling for tasks calling external services
- Always use `timedelta` for timeout values, not strings
- Use function references for `parents` and `ctx.task_output()`, not strings
