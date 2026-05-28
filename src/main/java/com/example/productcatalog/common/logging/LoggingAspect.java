package com.example.productcatalog.common.logging;

import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;

/**
 * AOP aspect that logs entry, exit, and elapsed time for all handler methods.
 */
@Slf4j
@Aspect
@Component
public class LoggingAspect {

    @Around("execution(* com.example.productcatalog.command.handler..*(..)) || " +
            "execution(* com.example.productcatalog.query.handler..*(..))")
    public Object logHandlerExecution(ProceedingJoinPoint pjp) throws Throwable {
        String method = pjp.getSignature().toShortString();
        long start = System.currentTimeMillis();

        log.debug("→ {}", method);
        try {
            Object result = pjp.proceed();
            log.debug("← {} completed in {}ms", method, System.currentTimeMillis() - start);
            return result;
        } catch (Exception ex) {
            log.warn("✗ {} failed in {}ms: {}", method, System.currentTimeMillis() - start, ex.getMessage());
            throw ex;
        }
    }
}
