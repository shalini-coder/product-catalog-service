package com.example.productcatalog.command.model;

import lombok.Builder;
import lombok.Value;

import java.util.UUID;

/**
 * Command to decrease the stock quantity of a product.
 */
@Value
@Builder
public class RemoveStockCommand {
    UUID productId;
    int quantity;
}
