package com.example.productcatalog.common.constants;

/**
 * Machine-readable error codes included in {@link com.example.productcatalog.api.dto.ErrorResponse}.
 */
public final class ErrorCodes {

    public static final String PRODUCT_NOT_FOUND       = "PRODUCT_NOT_FOUND";
    public static final String INSUFFICIENT_STOCK      = "INSUFFICIENT_STOCK";
    public static final String VALIDATION_ERROR        = "VALIDATION_ERROR";
    public static final String UNAUTHORIZED            = "UNAUTHORIZED";
    public static final String FORBIDDEN               = "FORBIDDEN";
    public static final String INTERNAL_SERVER_ERROR   = "INTERNAL_SERVER_ERROR";

    private ErrorCodes() {}
}
