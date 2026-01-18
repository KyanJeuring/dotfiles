# ==================================================
# Docker lists & info
# ==================================================

## List running containers with status and ports
dps() {
  docker ps --format "table {{.ID}}\t{{.Label \"com.docker.compose.service\"}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" \
    | sed '1 s/service/SERVICES/' | column -t -s $'\t'
}

## List all containers with status and ports
dpsa() {
  docker ps -a --format "table {{.ID}}\t{{.Label \"com.docker.compose.service\"}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" \
    | sed '1 s/service/SERVICES/' | column -t -s $'\t'
}

## Grep running containers by name
dpsg() {
  if [ -z "$1" ]; then
    echo "Usage: dpsg <pattern>"
    return 1
  fi
  docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" | grep -i "$1"
}

## List docker compose services
dsvc() {
  docker compose ps --services
}

## Show container port mappings
dport() {
  docker ps --format "table {{.Names}}\t{{.Ports}}"
}

## Show IP address of a container
dip() {
  if [ -z "$1" ]; then
    echo "Usage: dip <container-name>"
    return 1
  fi
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1"
}

# ==================================================
# Docker compose stack management
# ==================================================

## Start docker compose services
dstart() {
  docker compose start
}

## Stop docker compose services
dstop() {
  docker compose stop
}

## Build and start docker stack
dcompose() {
  docker compose up -d --build --remove-orphans
}

## Stop and remove containers + volumes
ddown() {
  docker compose down -v
}

## Stop all running containers (system-wide)
dstopall() {
  docker ps -q | xargs -r docker stop
}


## Recreate docker stack with volume removal
drecompose() {
  info "Recreating docker stack with volume removal"
  docker compose down -v && docker compose up -d
  ok "Stack recreated"
}

## Restart docker stack with status messages
drebootstack() {
  info "Restarting docker stack"
  docker compose down || return 1
  docker compose up -d || return 1
  ok "Stack restarted"
}

## Remove the current docker compose stack and prune unused Docker resources system-wide
dstack_purge() {
  warn "This will remove the CURRENT compose stack and prune UNUSED Docker resources system-wide"
  warn "Images and volumes still in use will NOT be removed"
  confirm "Continue?" || return 1
  docker compose down -v || return 1
  docker system prune -f
  ok "Docker stack purged and unused resources pruned"
}

# ==================================================
# Docker logs & debugging
# ==================================================

## Follow logs for all services with optional line count (Ctrl+C to exit)
dlogs() {
  local lines="${1:-100}"
  docker compose logs -f --tail="$lines"
}

## Follow logs for a single service (Ctrl+C to exit)
dlog() {
  if [ -z "$1" ]; then
    echo "Usage: dlog <service-name>"
    return 1
  fi
  docker compose logs -f --tail=100 "$1"
}

## Show last logs for all services (paged)
dlogs_last() {
  local lines="${1:-100}"
  docker compose logs --tail="$lines" | less
}

## Show last logs for a single service (paged)
dlog_last() {
  if [ -z "$1" ]; then
    echo "Usage: dlog_last <service-name> [lines]"
    return 1
  fi
  local lines="${2:-100}"
  docker compose logs --tail="$lines" "$1" | less
}

## Live container resource usage (Ctrl+C to exit)
dstats() {
  docker stats
}

## Inspect a container (JSON output)
dinspect() {
  if [ -z "$1" ]; then
    echo "Usage: dinspect <container-name>"
    return 1
  fi
  docker inspect "$1" | less
}

# ==================================================
# Docker exec & run
# ==================================================

## Exec into a running container (default shell)
dexec() {
  if [ -z "$1" ]; then
    echo "Usage: dexec <service-name>"
    return 1
  fi
  docker compose exec "$1" sh
}

## Run one-off commands in a service
drun() {
  if [ -z "$1" ]; then
    echo "Usage: drun <service-name> <command>"
    return 1
  fi
  shift
  docker compose run --rm "$1" "$@"
}

# ==================================================
# Docker images & volumes
# ==================================================

## List images with size
dimg() {
  docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
}

## List docker volumes
dvol() {
  docker volume ls
}

## Remove a docker volume
dvolrm() {
  if [ -z "$1" ]; then
    echo "Usage: dvolrm <volume-name>"
    return 1
  fi
  docker volume rm "$1"
}

## Inspect a docker volume
dvolinspect() {
  if [ -z "$1" ]; then
    echo "Usage: dvolinspect <volume-name>"
    return 1
  fi
  docker volume inspect "$1"
}

# ==================================================
# Docker cleanup
# ==================================================

## Remove stopped containers
dclean() {
  docker container prune -f
}

## Remove dangling images
dcleani() {
  docker image prune -f
}

## Full cleanup (destructive)
dcleanall() {
  warn "Removing unused containers, images, and networks"
  confirm "Continue?" || return 1
  docker system prune -a
}

## Show what prune would remove
dprunewhat() {
  docker system prune --dry-run
}

# ==================================================
# Docker updates & rebuilds
# ==================================================

## Pull latest images
dpull() {
  docker compose pull
}

## Pull images and recreate containers
dupdate() {
  docker compose pull && docker compose up -d
}

## Rebuild and restart a single service
drebuild() {
  if [ -z "$1" ]; then
    echo "Usage: drebuild <service-name>"
    return 1
  fi
  docker compose build "$1" && docker compose up -d "$1"
}

## Rebuild all services without using cache
drebuildnocache() {
  docker compose build --no-cache && docker compose up -d
}

# ==================================================
# Docker networking
# ==================================================

## List docker networks
dnet() {
  docker network ls
}

## Inspect a docker network
dnetinspect() {
  if [ -z "$1" ]; then
    echo "Usage: dnetinspect <network-name>"
    return 1
  fi
  docker network inspect "$1"
}

# ==================================================
# Docker compose utilities
# ==================================================

## Show resolved docker compose config
dconfig() {
  docker compose config
}