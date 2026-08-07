# Using a specific Docker socket

act --container-daemon-socket unix:///path/to/docker.sock

# For Docker Desktop on macOS (common case)

act --container-daemon-socket unix://$HOME/.docker/run/docker.sock

Alternatively, you can set the DOCKER_HOST environment variable:

# Set for the current command

DOCKER_HOST=unix:///path/to/docker.sock act

# Or export for the session

export DOCKER_HOST=unix://$HOME/.docker/run/docker.sock
act

Or use Docker's built-in context switching:

# List available contexts

docker context ls

# Use a specific context

docker context use <context-name>

# Now act will use this context

act

For Docker Desktop on macOS, the socket is typically at ~/.docker/run/docker.sock.
You
can verify your current Docker context and socket location with:

docker context inspect
