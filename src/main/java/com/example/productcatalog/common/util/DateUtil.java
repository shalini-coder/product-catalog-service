package com.example.productcatalog.common.util;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;

/**
 * Date / time utility helpers.
 */
public final class DateUtil {

    public static final DateTimeFormatter ISO_FORMATTER =
            DateTimeFormatter.ISO_LOCAL_DATE_TIME;

    private DateUtil() {}

    public static String format(LocalDateTime dateTime) {
        return dateTime == null ? null : dateTime.format(ISO_FORMATTER);
    }

    public static LocalDateTime nowUtc() {
        return LocalDateTime.now(ZoneOffset.UTC);
    }
}
