package com.example.productcatalog.common.logging;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;

import java.util.Map;

/**
 * Thin wrapper that adds structured key-value pairs to every log statement
 * via MDC, then removes them after the call.
 *
 * <pre>{@code
 *   StructuredLogger.info(log, "Product created", Map.of("productId", id.toString()));
 * }</pre>
 */
public final class StructuredLogger {

    private StructuredLogger() {}

    public static void info(Logger logger, String message, Map<String, String> context) {
        context.forEach(MDC::put);
        try {
            logger.info(message);
        } finally {
            context.keySet().forEach(MDC::remove);
        }
    }

    public static void warn(Logger logger, String message, Map<String, String> context) {
        context.forEach(MDC::put);
        try {
            logger.warn(message);
        } finally {
            context.keySet().forEach(MDC::remove);
        }
    }

    public static Logger getLogger(Class<?> clazz) {
        return LoggerFactory.getLogger(clazz);
    }
}
