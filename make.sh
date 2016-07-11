#!/bin/bash

set -x

SERVICES=$(find . -name Dockerfile -exec dirname {} \;)
REGISTRY=corporate-docker-registry.rgs.cinimex.ru:5000/
REVISION=863315

cnt=$(docker run -d -ti -v $(pwd):/tmp/src --privileged rgs/springboot-s2i bash) && \
    docker exec -ti $cnt /usr/local/s2i/assemble && \
for j in $SERVICES ; do
    docker cp $cnt:/opt/app-root/src/source/build/libs/$j build
done
docker kill $cnt
docker rm -f $cnt

for d in $SERVICES ; do
    n=$(echo $d | sed 's|./||')
    docker build -t ${REGISTRY}rgs/$n:$REVISION -f $n/Dockerfile .
    docker push ${REGISTRY}rgs/$n:$REVISION
done
