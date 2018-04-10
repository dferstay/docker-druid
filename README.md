# Druid Docker Image

An image that can be used to deploy Druid to a Kubernetes (k8s) cluster envirionment.

## Contents

This image contains both the Druid distribution as well as Tranquility.

The default CMD for the image is `run-druid.sh`, a shell script that is capable
of running a single Druid service.  It is expected that k8s resource definitions
will provide a specific CMD for starting each specific service in production.
