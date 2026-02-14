⏺ TLDR: OrbStack with compose.yml

  # 1. Install OrbStack (Mac only)
  # https://orbstack.dev

  # 2. Start OrbStack (runs the Docker daemon)
  open -a OrbStack

  # 3. Run the compose stack
  docker compose up

  # Or with Dagster orchestration:
  docker compose -f compose.orchestrator.yml up

  # For concurrent instances, set COMPOSE_ID:
  COMPOSE_ID=1 docker compose up  # Starts on ports 13500, 15432, etc.

  That's it—OrbStack provides the Docker daemon, so standard docker compose commands
  work exactly like Docker Desktop. The stack includes PostgreSQL, Kafka, API, Tasker,
  Workers, and Hatchet (workflow engine).

TLDR: Docker vs OrbStack Switching

  Both can run simultaneously, but Docker CLI connects to only one daemon at a time. Use
   contexts to switch:

  # Check which is active (shows *)
  docker context ls

  # Switch to OrbStack
  docker context use orbstack

  # Switch to Docker Desktop
  docker context use desktop-linux

  # Verify connection
  docker info | grep "Context\|Server Version"

  What happens:
  - Each maintains its own containers, images, and volumes
  - Running containers in one won't appear in the other
  - Switching contexts doesn't stop containers—they keep running in their respective
  daemon
  - Port conflicts can occur if both run containers on same ports

  Quick check:
  # See where your containers are running
  docker ps

  If you see nothing but expect containers, you're probably on the wrong context. Switch
   and check again.
