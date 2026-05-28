package com.example.productcatalog.api.controller;

import com.example.productcatalog.api.dto.ProductRequest;
import com.example.productcatalog.api.dto.ProductResponse;
import com.example.productcatalog.command.handler.ProductCommandHandler;
import com.example.productcatalog.command.model.AddProductCommand;
import com.example.productcatalog.command.model.AddStockCommand;
import com.example.productcatalog.command.model.RemoveStockCommand;
import com.example.productcatalog.command.model.UpdateProductCommand;
import com.example.productcatalog.query.handler.ProductQueryHandler;
import com.example.productcatalog.query.model.GetAllProductsQuery;
import com.example.productcatalog.query.model.GetProductQuery;
import com.example.productcatalog.query.model.SearchProductsByNameQuery;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.List;
import java.util.UUID;

/**
 * REST controller for the Product Catalog API (v1).
 *
 * <p>Thin adapter: every method translates the HTTP request into a command or query,
 * delegates to the appropriate handler, and maps the result back to a response body.
 * All exception handling lives in {@link com.example.productcatalog.api.exception.GlobalExceptionHandler}.
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/products")
@Tag(name = "Products", description = "Product Catalog management API")
@SecurityRequirement(name = "Bearer Authentication")
@RequiredArgsConstructor
public class ProductController {

    private final ProductCommandHandler commandHandler;
    private final ProductQueryHandler   queryHandler;

    // ── Write endpoints ───────────────────────────────────────────────────────

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a product")
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "Created"),
        @ApiResponse(responseCode = "400", description = "Validation error"),
        @ApiResponse(responseCode = "401", description = "Unauthenticated"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<Void> createProduct(@Valid @RequestBody ProductRequest request) {
        log.info("POST /api/v1/products — name={}", request.getName());

        UUID id = commandHandler.handle(
                AddProductCommand.builder()
                        .name(request.getName())
                        .description(request.getDescription())
                        .price(request.getPrice())
                        .build());

        return ResponseEntity
                .created(URI.create("/api/v1/products/" + id))
                .build();
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Update a product")
    @ApiResponses({
        @ApiResponse(responseCode = "204", description = "Updated"),
        @ApiResponse(responseCode = "400", description = "Validation error"),
        @ApiResponse(responseCode = "404", description = "Not found")
    })
    public ResponseEntity<Void> updateProduct(
            @PathVariable UUID id,
            @Valid @RequestBody ProductRequest request) {
        log.info("PUT /api/v1/products/{}", id);

        commandHandler.handle(
                UpdateProductCommand.builder()
                        .productId(id)
                        .name(request.getName())
                        .description(request.getDescription())
                        .price(request.getPrice())
                        .build());

        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/stock")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Add stock to a product")
    public ResponseEntity<Void> addStock(
            @PathVariable UUID id,
            @RequestParam @Min(1) int quantity) {
        log.info("POST /api/v1/products/{}/stock?quantity={}", id, quantity);

        commandHandler.handle(AddStockCommand.builder()
                .productId(id)
                .quantity(quantity)
                .build());

        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{id}/stock")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Remove stock from a product")
    public ResponseEntity<Void> removeStock(
            @PathVariable UUID id,
            @RequestParam @Min(1) int quantity) {
        log.info("DELETE /api/v1/products/{}/stock?quantity={}", id, quantity);

        commandHandler.handle(RemoveStockCommand.builder()
                .productId(id)
                .quantity(quantity)
                .build());

        return ResponseEntity.ok().build();
    }

    // ── Read endpoints ────────────────────────────────────────────────────────

    @GetMapping("/{id}")
    @Operation(summary = "Get a product by ID")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Found"),
        @ApiResponse(responseCode = "404", description = "Not found")
    })
    public ResponseEntity<ProductResponse> getProduct(
            @PathVariable @Parameter(description = "Product UUID") UUID id) {
        log.debug("GET /api/v1/products/{}", id);

        ProductResponse body = ProductResponse.from(
                queryHandler.handle(new GetProductQuery(id)));

        return ResponseEntity.ok(body);
    }

    @GetMapping
    @Operation(summary = "List all products (paginated)")
    public ResponseEntity<Page<ProductResponse>> getAllProducts(
            @PageableDefault(size = 20) Pageable pageable) {
        log.debug("GET /api/v1/products — pageable={}", pageable);

        Page<ProductResponse> page =
                queryHandler.handle(new GetAllProductsQuery(pageable))
                            .map(ProductResponse::from);

        return ResponseEntity.ok(page);
    }

    @GetMapping("/search")
    @Operation(summary = "Search products by name")
    public ResponseEntity<List<ProductResponse>> searchByName(
            @RequestParam @Parameter(description = "Partial product name") String name) {
        log.debug("GET /api/v1/products/search?name={}", name);

        List<ProductResponse> results =
                queryHandler.handle(new SearchProductsByNameQuery(name))
                            .stream()
                            .map(ProductResponse::from)
                            .toList();

        return ResponseEntity.ok(results);
    }
}
