#!/bin/bash

REGISTRY=corporate-docker-registry.rgs.cinimex.ru:5000
NAMESPACE=rgs
IMAGE_NAME=openshift-spring-cloud-test
RELEASE=863315

docker tag $IMAGE_NAME:base $REGISTRY/$NAMESPACE/$IMAGE_NAME:$RELEASE
docker push $REGISTRY/$NAMESPACE/$IMAGE_NAME:$RELEASE
