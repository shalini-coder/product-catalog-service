package com.example.productcatalog.common.constants;

/**
 * Application-wide constants.
 */
public final class AppConstants {

    public static final String API_VERSION          = "v1";
    public static final String API_BASE_PATH        = "/api/" + API_VERSION;
    public static final String CORRELATION_ID_HEADER = "X-Correlation-Id";
    public static final String DEFAULT_PAGE_SIZE    = "20";
    public static final int    MAX_PAGE_SIZE        = 100;

    private AppConstants() {}
}
