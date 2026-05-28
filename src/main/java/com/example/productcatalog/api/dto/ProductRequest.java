package com.example.productcatalog.api.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;
import lombok.Value;
import lombok.extern.jackson.Jacksonized;

import java.math.BigDecimal;

/**
 * API request body for create and update product operations.
 */
@Value
@Builder
@Jacksonized
public class ProductRequest {

    @NotBlank(message = "Product name cannot be blank")
    String name;

    String description;

    @NotNull(message = "Price is required")
    @DecimalMin(value = "0.01", message = "Price must be greater than zero")
    BigDecimal price;
}
