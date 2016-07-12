#!/bin/bash

REGISTRY := corporate-docker-registry.rgs.cinimex.ru:5000
REGISTRY_NS := 
IMAGE_NAME := openshift-spring-cloud-test
RELEASE := 863315

OS_PROJECT_NAME := openshift-spring-cloud-test

PROJECT_SOURRCE := http://gitlab.apps.rgs.cinimex.ru/alice/openshift-spring-cloud-test.git

APP_DOMAIN := apps.rgs.cinimex.ru

BACKEND_A_APP := backend-service-a
BACKEND_B_APP := backend-service-b
CONSUL_APP := consul
FRONTEND_APP := frontend-service
REDIS_APP := redis
SPLUNK_APP := splunk
SPLUNK_TOKEN := DA044211-D1E3-45F5-8025-36311DA590C3

all: list-targets
list-targets:
	@echo
	@grep '^[^#[:space:]].*:[[:space:]]\+#' Makefile
	@echo

clean-back-a: # remove backend-service-a application resources
	oc delete -l app=$(BACKEND_A_APP) all

clean-back-b: # remove backend-service-b application resources
	oc delete -l app=$(BACKEND_B_APP) all

clean-consul: # remove consul application resources
	oc delete -l app=$(CONSUL_APP) all

clean-front: # remove frontend-service application resources
	oc delete -l app=$(FRONTEND_APP) all

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
	oc -n $(OS_PROJECT_NAME) \
	    new-app \
		--name $(SPLUNK_APP) \
		-e SPLUNK_START_ARGS="--accept-license" \
	        outcoldman/splunk:6.4.1
	oc -n $(OS_PROJECT_NAME) \
	    volume dc/$(SPLUNK_APP) \
		--add \
		--overwrite \
		--claim-size='10Gi' \
		-t persistentVolumeClaim \
		--name=splunk-volume-2

	oc expose service $(SPLUNK_APP) --port=8080 --hostname=$(SPLUNK_APP).$(APP_DOMAIN)
	@echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	@echo "Please path $(SPLUNK_APP) to run in privileged mode" 

os-splunk-app-indeces: # create indeces into splunk app
	@echo "Not implemented yet"
	@/bin/false

os-redis-app-create: # create new application (redis) based on offical redis docker image
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name $(REDIS_APP) \
	    -e REDIS_START_ARGS="--appendonly yes" \
	    corporate-docker-registry.rgs.cinimex.ru:5000/rgs/redis
	oc -n $(OS_PROJECT_NAME) \
	    volume dc/$(REDIS_APP) \
		--add \
		--overwrite \
		--claim-size='100Mi' \
		-t persistentVolumeClaim \
		--name=redis-volume-1

os-consul-app-create: # create new application (consul)
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name $(CONSUL_APP) \
	    corporate-docker-registry.rgs.cinimex.ru:5000/rgs/consul
q	@echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	@echo "Please path $(CONSUL_APP) to run in privileged mode" 

os-backend-a-app-create: # create new application (backend-a)
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name $(BACKEND_A_APP) \
	    $(PROJECT_SOURRCE) \
	    --context-dir=backend-service \
	    -e SPRING_APPLICATION_NAME=$(BACKEND_A_APP) \
	    -e SPRING_CLOUD_CONSUL_HOST=$(CONSUL_APP) \
	    -e LOGGING_BUSINESS_INDEX_NAME=businessoperations \
	    -e LOGGING_DIRECTORY=logs \
	    -e LOGGING_ENABLE_LOG_TO_FILE=true \
	    -e LOGGING_ENABLE_LOG_TO_SPLUNK=true \
	    -e LOGGING_ENVIRONMENT=poc \
	    -e LOGGING_LEVEL=INFO \
	    -e LOGGING_NODE=someNiceNode \
	    -e LOGGING_SLOWQUERY_INDEX_NAME=acme-slowquery \
	    -e LOGGING_SPARSE=true \
	    -e LOGGING_SPLUNK_HOST=$(SPLUNK_APP) \
	    -e LOGGING_SPLUNK_PORT=8088 \
	    -e LOGGING_SPLUNK_TOKEN=$(SPLUNK_TOKEN) \
	    -e LOGGING_TECH_INDEX_NAME=acme
#	oc -n $(OS_PROJECT_NAME) \
#	    volume $(BACKEND_A_APP) \
#		--add \
#		--overwrite \
#		--claim-size='3Gi' \
#		-t persistentVolumeClaim \
#		--name=backend-service-a

os-backend-b-app-create: # create new application (backend-b)
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name $(BACKEND_B_APP) \
	    $(PROJECT_SOURRCE) \
	    --context-dir=backend-service \
	    -e SPRING_APPLICATION_NAME=$(BACKEND_B_APP) \
	    -e SPRING_CLOUD_CONSUL_HOST=$(CONSUL_APP) \
	    -e LOGGING_BUSINESS_INDEX_NAME=businessoperations \
	    -e LOGGING_DIRECTORY=logs \
	    -e LOGGING_ENABLE_LOG_TO_FILE=true \
	    -e LOGGING_ENABLE_LOG_TO_SPLUNK=true \
	    -e LOGGING_ENVIRONMENT=poc \
	    -e LOGGING_LEVEL=INFO \
	    -e LOGGING_NODE=someNiceNode \
	    -e LOGGING_SLOWQUERY_INDEX_NAME=acme-slowquery \
	    -e LOGGING_SPARSE=true \
	    -e LOGGING_SPLUNK_HOST=$(SPLUNK_APP) \
	    -e LOGGING_SPLUNK_PORT=8088 \
	    -e LOGGING_SPLUNK_TOKEN=$(SPLUNK_TOKEN) \
	    -e LOGGING_TECH_INDEX_NAME=acme
#	oc -n $(OS_PROJECT_NAME) \
#	    volume $(BACKEND_B_APP) \
#		--add \
#		--overwrite \
#		--claim-size='3Gi' \
#		-t persistentVolumeClaim \
#		--name=backend-service-a

os-frontend-app-create: # create new application (frontend-b)
	echo oc -n $(OS_PROJECT_NAME) new-app \
	    --name $(FRONTEND_APP) \
	    $(PROJECT_SOURRCE) \
	    --context-dir=backend-service \
	    -e SPRING_APPLICATION_NAME=$(FRONTEND_APP) \
	    -e SPRING_CLOUD_CONSUL_HOST=$(CONSUL_APP) \
	    -e CACHING_REDIS_HOST=redis \
	    -e CACHING_REDIS_PORT=6379 \
	    -e LOGGING_BUSINESS_INDEX_NAME=businessoperations \
	    -e LOGGING_DIRECTORY=logs \
	    -e LOGGING_ENABLE_LOG_TO_FILE=true \
	    -e LOGGING_ENABLE_LOG_TO_SPLUNK=true \
	    -e LOGGING_ENVIRONMENT=poc \
	    -e LOGGING_LEVEL=INFO \
	    -e LOGGING_NODE=someNiceNode \
	    -e LOGGING_SLOWQUERY_INDEX_NAME=acme-slowquery \
	    -e LOGGING_SPARSE=true \
	    -e LOGGING_SPLUNK_HOST=$(SPLUNK_APP) \
	    -e LOGGING_SPLUNK_PORT=8088 \
	    -e LOGGING_SPLUNK_TOKEN=$(SPLUNK_TOKEN) \
	    -e LOGGING_TECH_INDEX_NAME=acme
