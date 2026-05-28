package com.example.productcatalog.api.dto;

import lombok.Builder;
import lombok.Value;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Standardised error body returned by the {@link com.example.productcatalog.api.exception.GlobalExceptionHandler}.
 */
@Value
@Builder
public class ErrorResponse {

    int status;
    String error;
    String message;
    String path;
    LocalDateTime timestamp;
    List<String> validationErrors;
}
