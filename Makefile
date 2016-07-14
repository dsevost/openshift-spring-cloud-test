
REGISTRY = corporate-docker-registry.rgs.cinimex.ru:5000
REGISTRY_NS = rgs
IMAGE_NAME = openshift-spring-cloud-test
RELEASE = 863315

OS_PROJECT_NAME = openshift-spring-cloud-test-dev

PROJECT_SOURRCE = http://gitlab.apps.rgs.cinimex.ru/alice/openshift-spring-cloud-test.git

APP_DOMAIN = apps.rgs.cinimex.ru

BACKEND_A_APP = backend-service-a
BACKEND_B_APP = backend-service-b
BASE_IS_NAME = base-image-stream
CONSUL_APP = consul
FRONTEND_APP = frontend-service
REDIS_APP = redis
SPLUNK_APP = splunk
SPLUNK_AUTH=-auth admin:changeme
SPLUNK_TOKEN = '<change me>'
SPLUNK_URI=-uri https://localhost:8089/

TINY_1_VOL_SIZE=100Mi
SMALL_1_VOL_SIZE=512Mi
SMALL_2_VOL_SIZE=1Gi
MEDIUM_1_VOL_SIZE=3Gi
MEDIUM_2_VOL_SIZE=6Gi
LARGE_1_VOL_SIZE=10Gi
LARGE_2_VOL_SIZE=20Gi

main: list-public-targets
list-public-targets:
	@echo
	@grep '^[^#[:space:]].*:[[:space:]]\+#' Makefile
	@echo

s2i:
	s2i \
	    build \
		$(PROJECT_SOURRCE) \
		rgs/springboot-s2i \
		$(IMAGE_NAME):base \
		    --incremental=true

docker-tag: 					# tag just built docker image
	docker tag $(IMAGE_NAME):base $(REGISTRY)/$(REGISTRY_NS)/$(IMAGE_NAME):$(RELEASE)

docker-push: 					# tag just tagged docker image to corporate registry
	docker push $(REGISTRY)/$(REGISTRY_NS)/$(IMAGE_NAME):$(RELEASE)

os-create-project: 				# switch (or create) openshift project
	oc project $(OS_PROJECT_NAME) || oc new-project $(OS_PROJECT_NAME)
	oc status
	@echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	@echo "Adding default service account to privileged SCC (SPLUNK and CONSUL require root privileges to be running)"
	@echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	oadm policy add-scc-to-user privileged system:serviceaccount:$(OS_PROJECT_NAME):default

os-splunk-app-create: 				# create new application (SPLUNK) based on outcoldman/splunk:6.4.1 docker image
	oc -n $(OS_PROJECT_NAME) \
	    new-app \
		--name $(SPLUNK_APP) \
		-e SPLUNK_START_ARGS="--accept-license" \
	        outcoldman/splunk:6.4.1
	@echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	oc deploy $(SPLUNK_APP) --cancel=true || /bin/true
	oc patch dc $(SPLUNK_APP) -p '{ "spec": { "template": { "spec": { "containers": [{ "name": "$(SPLUNK_APP)", "securityContext": { "privileged": true } }] } } } }'
	oc -n $(OS_PROJECT_NAME) \
	    volume dc/$(SPLUNK_APP) \
		--add \
		--overwrite \
		--claim-size=$(LARGE_1_VOL_SIZE) \
		-t persistentVolumeClaim \
		--claim-name=splunk-volume-2 \
		--name=splunk-volume-2
	oc label pvc splunk-volume-2 app=$(SPLUNK_APP)
	oc expose service $(SPLUNK_APP) # --hostname=$(SPLUNK_APP).$(APP_DOMAIN)
	oc patch route $(SPLUNK_APP) -p '{ "spec": { "port": { "targetPort": "8000-tcp" } } }'

os-splunk-app-configure: POD := $(shell oc get pods | awk ' /splunk-[0-9]-[a-z0-9]+[[:space:]]+1\/1[[:space:]]+Running/ { print $$1; }')
os-splunk-app-configure:			# create indeces into splunk app
	if [ "$(POD)" = "" ] ; then \
	    echo "Could not find running splunk POD, wait for running state and try again" ; \
	    exit 1 ; \
	fi
	oc rsh $(POD) /bin/bash -c "\
	    export PATH=\$$PATH:/opt/splunk/bin ; \
	    for i in acme acme-slowquery businessoperations ; do \
		splunk remove index \$$i >/dev/null 2>&1 ; \
		splunk add index \$$i || exit 1; \
	    done ; \
	    splunk http-event-collector enable -enable-ssl 0 $(SPLUNK_URI) $(SPLUNK_AUTH) || exit 1 ; \
	    splunk http-event-collector delete http-token $(SPLUNK_URI) $(SPLUNK_AUTH) > /dev/null 2>&1 ; \
	    splunk http-event-collector create http-token 'HTTP token' \
		-index acme -indexes acme,acme-slowquery,businessoperations \
		$(SPLUNK_URI) $(SPLUNK_AUTH) || exit 1 ; \
	"

os-imagestream-create-base: 			# create base image stream for backend and frontend services
	@echo "\
	{\
	  \"apiVersion\": \"v1\", \
	  \"kind\": \"ImageStream\", \
	  \"metadata\": { \
	    \"name\": \"$(BASE_IS_NAME)\" \
	  }, \
	  \"spec\": { \
	    \"tags\": [ \
	      { \
	        \"from\": { \
	          \"kind\": \"DockerImage\", \
	          \"name\": \"$(REGISTRY)/$(REGISTRY_NS)/$(IMAGE_NAME):$(RELEASE)\" \
	        }, \
	        \"importPolicy\": {}, \
	        \"name\": \"latest\" \
	      } \
	    ] \
	  } \
	} \
	" | oc create -f -

os-redis-app-create: 				# create new application (redis)
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name $(REDIS_APP) \
	    -e REDIS_START_ARGS="--appendonly yes" \
	    $(REGISTRY)/$(REGISTRY_NS)/redis
	oc -n $(OS_PROJECT_NAME) \
	    volume dc/$(REDIS_APP) \
		--add \
		--overwrite \
		--claim-size=$(TINY_1_VOL_SIZE) \
		-t persistentVolumeClaim \
		--claim-name=redis-volume-1 \
		--name=redis-volume-1
	oc label pvc redis-volume-1 app=$(REDIS_APP)

os-consul-app-create: 				# create new application (consul)
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name $(CONSUL_APP) \
	    $(REGISTRY)/$(REGISTRY_NS)/consul
	@echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	oc deploy $(CONSUL_APP) --cancel=true || /bin/true
	oc patch dc $(CONSUL_APP) -p '{ "spec": { "template": { "spec": { "containers": [{ "name": "$(CONSUL_APP)", "securityContext": { "privileged": true } }] } } } }'
	oc -n $(OS_PROJECT_NAME) \
	    volume dc/$(CONSUL_APP) \
		--add \
		--overwrite \
		--claim-size=$(TINY_1_VOL_SIZE) \
		-t persistentVolumeClaim \
		--claim-name=consul-volume-1 \
		--name=consul-volume-1
	oc label pvc consul-volume-1 app=$(CONSUL_APP)

os-backend-a-app-create: 			# create new application (backend-a)
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
	oc -n $(OS_PROJECT_NAME) \
	    volume dc/$(BACKEND_A_APP) \
		--add \
		--overwrite \
		--claim-size=$(MEDIUM_1_VOL_SIZE) \
		-t persistentVolumeClaim \
		--mount-path=/logs \
		--claim-name=backend-service-a-1 \
		--name=backend-service-1
	oc label pvc backend-service-a-1 app=$(BACKEND_A_APP)

os-backend-b-app-create: 			# create new application (backend-b)
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
	oc -n $(OS_PROJECT_NAME) \
	    volume dc/$(BACKEND_B_APP) \
		--add \
		--overwrite \
		--claim-size=$(MEDIUM_1_VOL_SIZE) \
		-t persistentVolumeClaim \
		--mount-path=/logs \
		--claim-name=backend-service-b-1 \
		--name=backend-service-1
	oc label pvc backend-service-b-1 app=$(BACKEND_B_APP)

os-frontend-app-create: 			# create new application (frontend-service)
	oc -n $(OS_PROJECT_NAME) new-app \
	    --name $(FRONTEND_APP) \
	    $(PROJECT_SOURRCE) \
	    --context-dir=frontend-service \
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
	oc -n $(OS_PROJECT_NAME) \
	    volume dc/$(FRONTEND_APP) \
		--add \
		--overwrite \
		--claim-size=$(MEDIUM_1_VOL_SIZE) \
		-t persistentVolumeClaim \
		--mount-path=/logs \
		--claim-name=frontend-service-1 \
		--name=frontend-service-1
	oc label pvc frontend-service-1 app=$(FRONTEND_APP)
	oc expose service $(FRONTEND_APP) --hostname=$(OS_PROJECT_NAME).$(APP_DOMAIN)
	oc patch route $(FRONTEND_APP) -p '{ "spec": { "path": "/hello/" } }'

update-splunk-token: POD := $(shell oc get pods | awk ' /splunk-[0-9]-[a-z0-9]+[[:space:]]+1\/1[[:space:]]+Running/ { print $$1; }')
update-splunk-token: SPLUNK_TOKEN := $(shell oc rsh $(POD) /bin/bash -c "/opt/splunk/bin/splunk http-event-collector list -uri https://localhost:8089/ -auth admin:changeme |grep http-token -A 1 | grep token= | cut -d = -f 2")
update-splunk-token: 				# update SPLUNK token for services
	if [ "$(POD)" = "" ] ; then \
	    echo "Could not find running splunk POD, wait for running state and try again" ; \
	    exit 1 ; \
	fi
	for s in $(BACKEND_A_APP) $(BACKEND_B_APP) $(FRONTEND_APP) ; do \
	    oc -n $(OS_PROJECT_NAME) \
		env dc $$s \
		    LOGGING_SPLUNK_TOKEN=$(SPLUNK_TOKEN) ; \
	done

pvc: none
all: none
none:

clean-all: clean-front clean-back-a clean-back-b clean-redis clean-consul clean-splunk clean-base-is

clean-base-is: 					# remove base-image-stream  resources
	oc delete is $(BASE_IS_NAME)

clean-back-a: 					# remove backend-service-a application resources
	oc delete -l app=$(BACKEND_A_APP) all
	oc delete -l app=$(BACKEND_A_APP) pvc

clean-back-b: 					# remove backend-service-b application resources
	oc delete -l app=$(BACKEND_B_APP) all
	oc delete -l app=$(BACKEND_B_APP) pvc

clean-consul: 					# remove consul application resources
	oc delete -l app=$(CONSUL_APP) all
	oc delete -l app=$(CONSUL_APP) pvc

clean-front: 					# remove frontend-service application resources
	oc delete -l app=$(FRONTEND_APP) all
	oc delete -l app=$(FRONTEND_APP) pvc

clean-redis: 					# remove redis application resources
	oc delete -l app=$(REDIS_APP) all
	oc delete -l app=$(REDIS_APP) pvc

clean-splunk: 					# remove redis application resources
	oc delete -l app=$(SPLUNK_APP) all
	oc delete -l app=$(SPLUNK_APP) pvc

