FROM corporate-docker-registry.rgs.cinimex.ru:5000/rgs/openshift-spring-cloud-test:863315
MAINTAINER dsevosty@redhat.com

# expose ports
EXPOSE 8080

#remote debugging port, shouldn't be used in production
#EXPOSE 5005

ENV \
  SERVICE_NAME=backend-service

# setup startup command
CMD ["bash", "-c", "java -jar  \
 ${JAVA_OPTS} \
 -Dlogging.business.index.name=$LOGGING_BUSINESS_INDEX_NAME \
 -Dlogging.directory=$LOGGING_DIRECTORY \
 -Dlogging.enable.log.to.file=$LOGGING_ENABLE_LOG_TO_FILE \
 -Dlogging.enable.log.to.splunk=$LOGGING_ENABLE_LOG_TO_SPLUNK \
 -Dlogging.environment=$LOGGING_ENVIRONMENT \
 -Dlogging.level=$LOGGING_LEVEL \
 -Dlogging.node=$LOGGING_NODE \
 -Dlogging.slowquery.index.name=$LOGGING_SLOWQUERY_INDEX_NAME \
 -Dlogging.sparse=$LOGGING_SPARSE \
 -Dlogging.splunk.host=$LOGGING_SPLUNK_HOST \
 -Dlogging.splunk.port=$LOGGING_SPLUNK_PORT \
 -Dlogging.splunk.token=$LOGGING_SPLUNK_TOKEN \
 -Dlogging.tech.index.name=$LOGGING_TECH_INDEX_NAME \
 /${SERVICE_NAME}.jar"]

RUN \
  mv $DEPLOY_DIR/${SERVICE_NAME}.jar / \
  && \
  rm -rf $DEPLOY_DIR/*.jar
