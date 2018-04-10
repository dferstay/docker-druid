#!/bin/bash
#
# NAME:
#   wait-for-dependencies.sh - waits for services that Druid depends on to start up.
#
# USAGE:
#  wait-for-dependencies.sh [ADDR..]
#
# ADDR:
#  A <host>:<port> pair that specifies the location of an additional service to
#  wait for.  For example, A non-AWS S3 storage service such as minio.

ZK_KEY="druid.zk.service.host"
MD_STORAGE_URI_KEY="druid.metadata.storage.connector.connectURI"
COMMON_RUNTIME_PROPS="/druid/conf/druid/_common/common.runtime.properties"

# Pull the ZooKeeper service host out of the configuration
ZK_HOST=$(grep "^$ZK_KEY" "$COMMON_RUNTIME_PROPS" |
                 awk -F= '{print $2}' |
                 sed 's/^[[:space:]]*//' |
                 sed 's/[[:space:]]*$//')
if [ -z "$ZK_HOST" ]; then
    echo "Could not locate locate $ZK_KEY in $COMMON_RUNTIME_PROPS" >&2
    exit 1
fi

# Pull the metadata storage jdbc URI out of the configuration and
# parse the service host and port.  URIs are of the form:
# jdbc:postgresql://postgres:5432/druid
MD_STORAGE_HOST_AND_PORT=$(grep "^$MD_STORAGE_URI_KEY" "$COMMON_RUNTIME_PROPS" |
                                  awk -F= '{print $2}' |
                                  sed 's/^[[:space:]]*//' |
                                  sed 's/[[:space:]]*$//' |
                                  awk -F/ '{print $3}')
if [ -z "$MD_STORAGE_HOST_AND_PORT" ]; then
    echo "Could not locate $MD_STORAGE_URI_KEY in $COMMON_RUNTIME_PROPS" >&2
    exit 1
fi
MD_STORAGE_HOST=$(echo "$MD_STORAGE_HOST_AND_PORT" | awk -F: '{print $1}')
if [ -z "$MD_STORAGE_HOST" ]; then
    echo "Could not parse host from: '$MD_STORAGE_HOST_AND_PORT'" >&2
    exit 1
fi
MD_STORAGE_PORT=$(echo "$MD_STORAGE_HOST_AND_PORT" | awk -F: '{print $2}')
if [ -z "$MD_STORAGE_PORT" ]; then
    echo "Could not parse port from: '$MD_STORAGE_HOST_AND_PORT'" >&2
    exit 1
fi

# Wait for services
echo "Wait for ZooKeeper to get a DNS entry"
until nslookup "$ZK_HOST"; do
    echo "Waiting for DNS entry for ZooKeeper host: $ZK_HOST"
    sleep 2
done

echo "Wait for the ZooKeeper ensemble to become operational"
ZK_UP=0
until [ "$ZK_UP" -eq 1 ]; do
    RUOK=$(echo ruok | nc -w 1 "$ZK_HOST" 2181)
    if [ "$RUOK" != "imok" ]; then
        echo "Waiting for ZooKeeper host to be ready at: ${ZK_HOST}:2181"
        sleep 2
    else
        ZK_UP=1
    fi
done
echo "ZooKeeper service is up at: $ZK_HOST"
echo ""

echo "Wait for the metadata storage service to get a DNS entry"
until nslookup "$MD_STORAGE_HOST"; do
    echo "Waiting for DNS entry for metadata storage service: $MD_STORAGE_HOST"
    sleep 2
done

echo "Wait for metadata storage to become reachable on its service port"
until nc -w 1 "$MD_STORAGE_HOST" "$MD_STORAGE_PORT"; do
    echo "Waiting for metadata storage service to be ready at: ${MD_STORAGE_HOST}:${MD_STORAGE_PORT}"
    sleep 2
done
echo "Metadata Storage service is up at: ${MD_STORAGE_HOST}:${MD_STORAGE_PORT}"
echo ""

echo "Wait for additional services to start"
while [ "$1" != "" ]; do
    HOST=$(echo "$1" | awk -F: '{print $1}')
    if [ -z "$HOST" ]; then
        echo "Could not parse host from additional service: $1" >&2
        exit 1
    fi
    PORT=$(echo "$1" | awk -F: '{print $2}')
    if [ -z "$PORT" ]; then
        echo "Could not parse port from additional service: $1" >&2
        exit 1
    fi

    echo "Waiting for service '$HOST' to get a DNS entry"
    until nslookup "$HOST"; do
        echo "Waiting for DNS entry for service: $HOST"
        sleep 2
    done
    echo "Waiting for service to become rechable on its service port"
    until nc -w 1 "$HOST" "$PORT"; do
        echo "Waiting for service to be ready at: ${HOST}:${PORT}"
        sleep 2
    done
    echo "Service is up at: ${HOST}:${PORT}"
    echo ""

    shift
done
