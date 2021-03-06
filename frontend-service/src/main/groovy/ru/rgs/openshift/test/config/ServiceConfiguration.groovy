package ru.rgs.openshift.test.config

import groovy.util.logging.Slf4j
import info.developerblog.spring.thrift.annotation.ThriftClientsMap
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestMethod
import org.springframework.web.bind.annotation.RestController
import redis.clients.jedis.Jedis
import redis.clients.jedis.JedisCommands
import ru.rgs.openshift.test.THeaders
import ru.rgs.openshift.test.backend.TBackendReq
import ru.rgs.openshift.test.backend.TBackendService
/**
 * @author jihor (dmitriy_zhikharev@rgs.ru)
 *         (С) RGS Group, http://www.rgs.ru
 *         Created on 2016-07-06
 */
@RestController
@Slf4j
class ServiceConfiguration {
    @Value('#{"${caching.redis.host:127.0.0.1}"}')
    private String redisHost

    @Value('#{systemProperties["caching.redis.port"] ?: 6379}')
    private Integer redisPort

    @Bean
    DemoMapper demoMapper(){
        new DemoMapper()
    }

    @Bean
    JedisCommands jedis(){
        new Jedis(redisHost, redisPort)
    }

    @ThriftClientsMap(mapperClass = DemoMapper.class)
    Map<String, TBackendService.Client> serviceClients

    @RequestMapping(value = "/hello/{name}", method = RequestMethod.GET)
    String hello(@PathVariable String name) {
        log.info "Looking up cache for name $name..."
        def jedis = jedis()
        def cachedResponse = jedis.get(name)
        if (cachedResponse){
            return cachedResponse + " (this is a cached response)"
        }

        String backendAorB = name.length() % 2 == 0 ? "a" : "b"
        log.info "Using backend $backendAorB for name $name..."
        def response = serviceClients.get(backendAorB)
                                     .greet(new TBackendReq()
                                                    .setHeaders(new THeaders().setCorrelationid(UUID.randomUUID().toString()))
                                                    .setLastname(name))
        // NX - set key only if it doesn't exist
        // EX - expiration time is set in seconds
        // see http://redis.io/commands/SET
        jedis.set(name, response.message, "NX", "EX", 180)
        response.message
    }

}
