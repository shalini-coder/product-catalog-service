package com.example.productcatalog.common.util;

import java.util.UUID;

/**
 * Utility helpers for UUID operations.
 */
public final class UuidUtil {

    private UuidUtil() {}

    public static UUID generate() {
        return UUID.randomUUID();
    }

    /** Parses a string to UUID; returns {@code null} if the format is invalid. */
    public static UUID parseOrNull(String value) {
        if (value == null || value.isBlank()) return null;
        try {
            return UUID.fromString(value);
        } catch (IllegalArgumentException ex) {
            return null;
        }
    }
}
