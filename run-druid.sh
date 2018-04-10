#!/bin/bash
set -e
set -u

function usage() {
    help=$(cat <<EOF
NAME:
  run-druid.sh - start a druid service.

USAGE:
  run-druid.sh SERVER

SERVER:
  SERVER is the name of the druid service type that you want to start up.
  Valid values are:
  coordinator
  overlord
  historical
  broker
  middleManager
EOF
	)
    echo "$help" >&2
    exit 1
}

if [ "$#" -ne 1 ]; then
    usage
fi

# Validate the specified service type
SERVER="$1"
case "$SERVER" in
    coordinator)
	;;
    overlord)
	;;
    historical)
	;;
    broker)
	;;
    middleManager)
	;;
    *)
	usage
esac

exec java $(xargs < conf/druid/"$SERVER"/jvm.config) -cp "conf/druid/_common:conf/druid/$SERVER:lib/*" io.druid.cli.Main server "$SERVER"
