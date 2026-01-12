---
name: hatchet-skill
description: Guide development with Hatchet, an orchestration platform for durable workflows, background tasks, and AI agent pipelines in Python/TypeScript/Go.
---

# Hatchet Skill

Use when implementing or debugging workflows, tasks, or workers with the Hatchet SDK. Hatchet provides sub-25ms task dispatch, durable execution with PostgreSQL persistence, and automatic failure recovery.

## Core concepts

- **Workflow**: A class decorated with `@hatchet.workflow()` containing one or more tasks
- **Task**: A function decorated with `@hatchet.task()` or `@hatchet.durable_task()`
- **Worker**: A process that registers workflows and executes tasks
- **DAG**: Tasks within a workflow can define parent-child dependencies

## Workflow definition

```python
from hatchet_sdk import Hatchet
from pydantic import BaseModel

hatchet = Hatchet()

class ProcessInput(BaseModel):
    data: str

@hatchet.workflow(input_validator=ProcessInput)
class ProcessWorkflow:
    @hatchet.task()
    def extract(self, input: ProcessInput, context):
        return {"extracted": input.data.upper()}

    @hatchet.task()
    def transform(self, input: ProcessInput, context):
        # Access parent task output via context
        return {"transformed": True}
```

### Workflow options

| Parameter | Purpose |
|-----------|---------|
| `name` | Workflow identifier (defaults to class name) |
| `input_validator` | Pydantic model for input validation |
| `on_events` | List of event triggers |
| `on_crons` | List of cron expressions |
| `concurrency` | Max concurrent runs (int or expression) |
| `default_priority` | Scheduling priority (higher = sooner) |

## Task configuration

```python
from datetime import timedelta

@hatchet.task(
    name="process_data",
    retries=3,
    backoff_factor=2.0,
    backoff_max_seconds=300,
    execution_timeout=timedelta(seconds=120),
    concurrency=5,
)
def process(self, input, context):
    pass
```

### Standard vs durable tasks

| Type | Decorator | Use case |
|------|-----------|----------|
| Standard | `@hatchet.task()` | Simple, stateless operations |
| Durable | `@hatchet.durable_task()` | Long-running, fault-tolerant with checkpointing |

Durable tasks receive `DurableContext` for state persistence across failures.

## Worker setup

```python
async def lifespan():
    # Startup
    yield
    # Teardown

worker = hatchet.worker(
    name="my-worker",
    slots=50,           # Concurrent standard tasks
    durable_slots=100,  # Concurrent durable tasks
    labels={"region": "us-east-1"},
    workflows=[ProcessWorkflow],
    lifespan=lifespan,
)

worker.start()
```

## Triggering workflows

```python
# Programmatic execution
result = ProcessWorkflow.run(ProcessInput(data="hello"))

# Async execution
result = await ProcessWorkflow.aio_run(ProcessInput(data="hello"))

# Event-based (configure on_events in decorator)
hatchet.event.push("user:created", {"user_id": "123"})

# Cron-based (configure on_crons in decorator)
@hatchet.workflow(on_crons=["0 9 * * *"])
class DailyReport:
    pass
```

## Concurrency strategies

| Strategy | Behavior |
|----------|----------|
| `GROUP_ROUND_ROBIN` | Fair distribution across groups; queues when full |
| `CANCEL_IN_PROGRESS` | Cancels running tasks to prioritize new ones |
| `CANCEL_NEWEST` | Rejects new work; lets in-progress complete |

Use multiple concurrency expressions for hierarchical control (e.g., per-team + per-resource).

## Common patterns

### DAG with dependencies
Define parent tasks to create execution order. Child tasks wait for parents to complete.

### Input validation
Always use `input_validator` with Pydantic models for type safety.

### Error handling
- Set `retries` for transient failures
- Use `backoff_factor` for exponential backoff
- Set `execution_timeout` to bound long-running tasks
- Use durable tasks for operations requiring recovery

### Rate limiting
Use `rate_limits` parameter to respect external API limits.

## Debugging checklist

1. Verify worker is running and registered with control plane
2. Check workflow name matches between definition and trigger
3. Confirm input matches expected schema
4. Review task logs in Hatchet dashboard
5. Check for timeout exceeded (default: 60s execution, 5min schedule)

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
