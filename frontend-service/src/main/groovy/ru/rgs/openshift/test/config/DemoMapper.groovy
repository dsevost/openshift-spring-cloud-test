package ru.rgs.openshift.test.config

import info.developerblog.spring.thrift.client.AbstractThriftClientKeyMapper
import info.developerblog.spring.thrift.client.pool.ThriftClientKey
import ru.rgs.openshift.test.backend.TBackendService

/**
 *
 *
 * @author jihor (dmitriy_zhikharev@rgs.ru)
 * (С) RGS Group, http://www.rgs.ru
 * Created on 2016-07-07
 */
class DemoMapper extends AbstractThriftClientKeyMapper {
    protected HashMap<String, ThriftClientKey> mappings = ["a": ThriftClientKey.builder().
                                                                    clazz(TBackendService.Client.class).
                                                                    serviceName("backend-service-a").
                                                                    path("/backend").
                                                                    build(),
                                                           "b": ThriftClientKey.builder().
                                                                   clazz(TBackendService.Client.class).
                                                                   serviceName("backend-service-b").
                                                                   path("/backend").
                                                                   build()]

    @Override
    Map<String, ThriftClientKey> getMappings() {
        return mappings
    }
}
