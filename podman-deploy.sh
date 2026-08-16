#!/usr/bin/env bash
set -euo pipefail

BASE_PORT=8000
STATE_DIR="/var/lib/mydeploy"

mkdir -p "$STATE_DIR"


#######################################
# Helpers
#######################################

die() {
    echo "ERROR: $*" >&2
    exit 1
}


slugify() {
    echo "$1" | tr '/:@' '___'
}


state_dir() {
    echo "$STATE_DIR/$(slugify "$1")"
}


free_port() {
    local port=$BASE_PORT

    while ss -ltn | grep -q ":$port "; do
        port=$((port+1))
    done

    echo "$port"
}


digest() {
    local image="$1"

    podman image inspect "$image" \
        --format '{{.Digest}}' 2>/dev/null || true
}


#######################################
# Deploy
#######################################

deploy() {

    IMAGE="$1"

    [ -z "$IMAGE" ] && die "image required"

    DIR=$(state_dir "$IMAGE")

    mkdir -p "$DIR"

    ACTIVE="$DIR/active"
    VERSIONS="$DIR/versions"
    PINS="$DIR/pins"

    touch "$VERSIONS" "$PINS"


    echo "Checking $IMAGE"


    podman pull "$IMAGE"


    DIGEST=$(digest "$IMAGE")


    if grep -q "$DIGEST" "$VERSIONS"; then
        echo "Already deployed:"
        echo "$DIGEST"
        exit 0
    fi


    PORT=$(free_port)

    NAME="$(slugify "$IMAGE")-${DIGEST#sha256:}"
    NAME="${NAME:0:60}"


    echo "Deploying:"
    echo " image:  $IMAGE"
    echo " digest: $DIGEST"
    echo " port:   $PORT"


    podman run \
        -d \
        --name "$NAME" \
        --restart always \
        -p "$PORT:8080" \
        "$IMAGE"


    sleep 3


    if ! podman ps | grep -q "$NAME"; then
        die "container failed"
    fi


    echo "$NAME $DIGEST $PORT" >> "$VERSIONS"

    echo "$NAME" > "$ACTIVE"


    echo "Deployed successfully"
}


#######################################
# Status
#######################################

status() {

    IMAGE="$1"

    DIR=$(state_dir "$IMAGE")

    echo "Image:"
    echo "$IMAGE"

    echo

    echo "Active:"
    cat "$DIR/active" 2>/dev/null || echo none

    echo

    echo "Versions:"
    cat "$DIR/versions" 2>/dev/null || true

    echo

    echo "Pinned:"
    cat "$DIR/pins" 2>/dev/null || true
}


#######################################
# Pin
#######################################

pin() {

    IMAGE="$1"
    DIGEST="$2"

    DIR=$(state_dir "$IMAGE")

    mkdir -p "$DIR"

    touch "$DIR/pins"

    grep -qx "$DIGEST" "$DIR/pins" || \
        echo "$DIGEST" >> "$DIR/pins"

    echo "Pinned $DIGEST"
}


#######################################
# Cleanup
#######################################

cleanup() {

    IMAGE="$1"

    DIR=$(state_dir "$IMAGE")

    VERSIONS="$DIR/versions"
    PINS="$DIR/pins"
    ACTIVE="$DIR/active"


    CURRENT=$(cat "$ACTIVE" 2>/dev/null || true)

    PREVIOUS=$(tail -2 "$VERSIONS" | awk '{print $1}')


    KEEP="$CURRENT $PREVIOUS"


    while read -r NAME DIGEST PORT; do

        [ -z "$NAME" ] && continue


        if echo "$KEEP" | grep -qw "$NAME"; then
            continue
        fi


        if grep -qx "$DIGEST" "$PINS"; then
            continue
        fi


        echo "Removing $NAME"

        podman rm -f "$NAME" || true

        sed -i "\|$NAME|d" "$VERSIONS"


    done < "$VERSIONS"
}


#######################################
# CLI
#######################################

case "${1:-}" in

deploy)
    deploy "$2"
    ;;

status)
    status "$2"
    ;;

pin)
    pin "$2" "$3"
    ;;

cleanup)
    cleanup "$2"
    ;;

*)
cat <<EOF

Usage:

Deploy:
  mydeploy deploy IMAGE

Example:
  mydeploy deploy ghcr.io/user/app:latest


Status:
  mydeploy status IMAGE


Pin:
  mydeploy pin IMAGE DIGEST


Cleanup:
  mydeploy cleanup IMAGE


EOF
;;

esac
