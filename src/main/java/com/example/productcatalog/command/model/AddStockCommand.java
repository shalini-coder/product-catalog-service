package com.example.productcatalog.command.model;

import lombok.Builder;
import lombok.Value;

import java.util.UUID;

/**
 * Command to increase the stock quantity of a product.
 */
@Value
@Builder
public class AddStockCommand {
    UUID productId;
    int quantity;
}
