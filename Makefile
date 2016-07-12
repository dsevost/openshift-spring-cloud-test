#!/bin/bash

REGISTRY := corporate-docker-registry.rgs.cinimex.ru:5000
REGISTRY_NS := 
IMAGE_NAME := openshift-spring-cloud-test
RELEASE := 863315

OS_PROJECT_NAME := openshift-spring-cloud-test

PROJECT_SOURRCE := http://gitlab.apps.rgs.cinimex.ru/alice/openshift-spring-cloud-test.git

CONSUL_APP := consul
REDIS_APP := redis
SPLUNK_APP := splunk

all: list-targets
list-targets:
	@echo
	@grep '^[^#[:space:]].*:[[:space:]]\+#' Makefile
	@echo

clean-consul: # remove consul application resources
	oc delete -l app=$(CONSUL_APP) all

clean-redis: # remove redis application resources
	oc delete -l app=$(REDIS_APP) all

clean-splunk: # remove redis application resources
	oc delete -l app=$(SPLUNK_APP) all

s2i:
	s2i \
	    build \
		http://gitlab.apps.rgs.cinimex.ru/alice/openshift-spring-cloud-test.git \
		rgs/springboot-s2i \
		openshift-spring-cloud-test:base \
		    --incremental=true

docker-tag: # tag just built docker image
	docker tag $(IMAGE_NAME):base $(REGISTRY)/$(REGISTRY_NS)/$(IMAGE_NAME):$(RELEASE)

docker-push: # tag just tagged docker image to corporate registry
	docker push $(REGISTRY)/$(REGISTRY_NS)/$(IMAGE_NAME):$(RELEASE)

os-create-project: # switch (or create) openshift project
	oc project $(OS_PROJECT_NAME) || oc new-project $(OS_PROJECT_NAME)
	oc status
	@echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	@echo "Adding default service account to privileged SCC (SPLUNK requires root privileges to be running)"
	@echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	oadm policy add-scc-to-user privileged system:serviceaccount:$(OS_PROJECT_NAME):default

os-splunk-app-create: # create new application (SPLUNK) based on outcoldman/splunk:6.4.1 docker image
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name $(SPLUNK_APP) \
	    -e SPLUNK_START_ARGS="--accept-license" \
	    outcoldman/splunk:6.4.1
	@echo "Please path $(SPLUNK_APP) to run in privileged mode" 

os-splunk-app-indeces: # create indeces into splunk app
	@echo "Not implemented yet"
	@/bin/false

os-redis-app-create: # create new application (redis) based on offical redis docker image
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name $(REDIS_APP) \
	    -e REDIS_START_ARGS="--appendonly yes" \
	    corporate-docker-registry.rgs.cinimex.ru:5000/rgs/redis

os-consul-app-create: # create new application (consul)
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name $(CONSUL_APP) \
	    corporate-docker-registry.rgs.cinimex.ru:5000/rgs/consul
	@echo "Please path $(CONSUL_APP) to run in privileged mode" 

os-backend-a-app-create: # create new application (backend-a)
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name backend-service-a \
	    $(PROJECT_SOURRCE) \
	    --context-dir=backend-service \
	    --param=SPRING_APPLICATION_NAME=backend-service-a \
	    --param=SPRING_CLOUD_CONSUL_HOST=172.17.0.5 \
	    --param=LOGGING_BUSINESS_INDEX_NAME=businessoperations \
	    --param=LOGGING_DIRECTORY=logs \
	    --param=LOGGING_ENABLE_LOG_TO_FILE=true \
	    --param=LOGGING_ENABLE_LOG_TO_SPLUNK=true \
	    --param=LOGGING_ENVIRONMENT=poc \
	    --param=LOGGING_LEVEL=INFO \
	    --param=LOGGING_NODE=someNiceNode \
	    --param=LOGGING_SLOWQUERY_INDEX_NAME=acme-slowquery \
	    --param=LOGGING_SPARSE=true \
	    --param=LOGGING_SPLUNK_HOST=\$${SPLUNK_SERVICE_HOST} \
	    --param=LOGGING_SPLUNK_PORT=\$${SPLUNK_SERVICE_PORT} \
	    --param=LOGGING_SPLUNK_TOKEN=8B9EA553-61D8-4FCD-AB7B-9F5D6CA94345 \
	    --param=LOGGING_TECH_INDEX_NAME=acme

os-backend-b-app-create: # create new application (backend-b)
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name backend-service-b \
	    $(PROJECT_SOURRCE) \
	    --context-dir=backend-service \
	    --param=SPRING_APPLICATION_NAME=backend-service-b \
	    --param=SPRING_CLOUD_CONSUL_HOST=172.17.0.5 \
	    --param=LOGGING_BUSINESS_INDEX_NAME=businessoperations \
	    --param=LOGGING_DIRECTORY=logs \
	    --param=LOGGING_ENABLE_LOG_TO_FILE=true \
	    --param=LOGGING_ENABLE_LOG_TO_SPLUNK=true \
	    --param=LOGGING_ENVIRONMENT=poc \
	    --param=LOGGING_LEVEL=INFO \
	    --param=LOGGING_NODE=someNiceNode \
	    --param=LOGGING_SLOWQUERY_INDEX_NAME=acme-slowquery \
	    --param=LOGGING_SPARSE=true \
	    --param=LOGGING_SPLUNK_HOST=\$${SPLUNK_SERVICE_HOST} \
	    --param=LOGGING_SPLUNK_PORT=\$${SPLUNK_SERVICE_PORT} \
	    --param=LOGGING_SPLUNK_TOKEN=8B9EA553-61D8-4FCD-AB7B-9F5D6CA94345 \
	    --param=LOGGING_TECH_INDEX_NAME=acme

os-frontend-app-create: # create new application (frontend-b)
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name frontend \
	    $(PROJECT_SOURRCE) \
	    --context-dir=frontend-service \
	    --param=SPRING_APPLICATION_NAME=fontend-service \
	    --param=SPRING_CLOUD_CONSUL_HOST=172.17.0.5 \
	    --param=CACHING_REDIS_HOST=172.17.0.4 \
	    --param=CACHING_REDIS_PORT=6379 \
	    --param=LOGGING_BUSINESS_INDEX_NAME=businessoperations \
	    --param=LOGGING_DIRECTORY=logs \
	    --param=LOGGING_ENABLE_LOG_TO_FILE=true \
	    --param=LOGGING_ENABLE_LOG_TO_SPLUNK=true \
	    --param=LOGGING_ENVIRONMENT=poc \
	    --param=LOGGING_LEVEL=INFO \
	    --param=LOGGING_NODE=someNiceNode \
	    --param=LOGGING_SLOWQUERY_INDEX_NAME=acme-slowquery \
	    --param=LOGGING_SPARSE=true \
	    --param=LOGGING_SPLUNK_HOST=\${SPLUNK_SERVICE_HOST} \
	    --param=LOGGING_SPLUNK_PORT=\${SPLUNK_SERVICE_PORT} \
	    --param=LOGGING_SPLUNK_TOKEN=8B9EA553-61D8-4FCD-AB7B-9F5D6CA94345 \
	    --param=LOGGING_TECH_INDEX_NAME=acme
