#!/usr/bin/env bats

# Debugging
teardown () {
	echo
	# TODO: figure out how to deal with this (output from previous run commands showing up along with the error message)
	echo "Note: ignore the lines between \"...failed\" above and here"
	echo
	echo "Status: $status"
	echo "Output:"
	echo "================================================================"
	echo "$output"
	echo "================================================================"
}

# Checks container health status (if available)
# @param $1 container id/name
_healthcheck ()
{
    local health_status
    health_status=$(docker inspect --format='{{json .State.Health.Status}}' "$1" 2>/dev/null)

    # Wait for 5s then exit with 0 if a container does not have a health status property
    # Necessary for backward compatibility with images that do not support health checks
    if [[ $? != 0 ]]; then
    echo "Waiting 10s for container to start..."
    sleep 10
    return 0
    fi

    # If it does, check the status
    echo $health_status | grep '"healthy"' >/dev/null 2>&1
}

# Waits for containers to become healthy
# For reasoning why we are not using  `depends_on` `condition` see here:
# https://github.com/docksal/docksal/issues/225#issuecomment-306604063
_healthcheck_wait ()
{
    # Wait for cli to become ready by watching its health status
    local container_name="${NAME}"
    local delay=5
    local timeout=30
    local elapsed=0

    until _healthcheck "$container_name"; do
    echo "Waiting for $container_name to become ready..."
    sleep "$delay";

    # Give the container 30s to become ready
    elapsed=$((elapsed + delay))
    if ((elapsed > timeout)); then
        echo-error "$container_name heathcheck failed" \
	"Container did not enter a healthy state within the expected amount of time." \
	"Try ${yellow}fin restart${NC}"
        exit 1
    fi
    done

    return 0
}

# Global skip
# Uncomment below, then comment skip in the test you want to debug. When done, reverse.
# SKIP=1

@test "Bare server" {
    [[ $SKIP == 1 ]] && skip

    ### Setup ###
    make ENV="-e VARNISH_BACKEND_HOST=127.0.0.1" start
    _healthcheck_wait

    ### Cleanup ###
    make clean
}

