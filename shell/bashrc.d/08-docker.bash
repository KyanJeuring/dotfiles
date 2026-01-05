# ==================================================
# Docker stack lifecycle
# ==================================================

## List running containers with status and ports
dps() {
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

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

## Restart docker stack
drestart() {
  docker compose down && docker compose up -d
}

## Stop all running containers
dstopall() {
  docker ps -aq | xargs -r docker stop
}

## Recreate docker stack with volume removal
drecompose() {
  docker compose down -v && docker compose up -d
}

## Restart docker compose stack (safe + verbose)
drebootstack() {
  info "Restarting docker stack"
  docker compose down || return 1
  docker compose up -d || return 1
  ok "Stack restarted"
}

## Fully reset docker stack (destructive)
dresetstack() {
  warn "This will remove containers, networks, and volumes"
  confirm "Continue?" || return 1

  docker compose down -v || return 1
  docker system prune -f
  ok "Docker stack fully reset"
}

# ==================================================
# Docker logs & debugging
# ==================================================

## Follow logs for all services
dlogs() {
  docker compose logs -f --tail=100
}

## Follow logs for a single service
dlog() {
  docker compose logs -f --tail=100 "$1"
}

## Live container resource usage
dstats() {
  docker stats
}

## Inspect a container (JSON output)
dinspect() {
  docker inspect "$1" | less
}

# ==================================================
# Docker exec & run
# ==================================================

## Exec into a running container (default shell)
dexec() {
  docker compose exec "$1" sh
}

## Run one-off commands in a service
drun() {
  docker compose run --rm "$@"
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

## Inspect a docker volume
dvolinspect() {
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
  docker compose build "$1" && docker compose up -d "$1"
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
  docker network inspect "$1"
}

# ==================================================
# Docker compose utilities
# ==================================================

## Show resolved docker compose config
dconfig() {
  docker compose config
}