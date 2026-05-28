package com.example.productcatalog.api.controller;

import com.example.productcatalog.api.dto.ProductRequest;
import com.example.productcatalog.command.handler.ProductCommandHandler;
import com.example.productcatalog.command.model.AddProductCommand;
import com.example.productcatalog.query.dto.ProductDto;
import com.example.productcatalog.query.handler.ProductQueryHandler;
import com.example.productcatalog.query.model.GetProductQuery;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(ProductController.class)
@DisplayName("ProductController")
class ProductControllerTest {

        @Autowired
        MockMvc mockMvc;
        @Autowired
        ObjectMapper mapper;

        @MockBean
        ProductCommandHandler commandHandler;
        @MockBean
        ProductQueryHandler queryHandler;

        // ── POST /api/v1/products ─────────────────────────────────────────────────

        @Test
        @WithMockUser(roles = "ADMIN")
        @DisplayName("POST /products should return 201 and Location header when valid")
        void createProduct_shouldReturn201() throws Exception {
                UUID newId = UUID.randomUUID();
                when(commandHandler.handle(any(AddProductCommand.class))).thenReturn(newId);

                ProductRequest request = ProductRequest.builder()
                                .name("Gaming Laptop")
                                .description("High-performance")
                                .price(new BigDecimal("1299.99"))
                                .build();

                mockMvc.perform(post("/api/v1/products")
                                .with(csrf())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(mapper.writeValueAsString(request)))
                                .andExpect(status().isCreated())
                                .andExpect(header().string("Location", "/api/v1/products/" + newId));
        }

        @Test
        @WithMockUser(roles = "ADMIN")
        @DisplayName("POST /products should return 400 when name is blank")
        void createProduct_shouldReturn400WhenNameBlank() throws Exception {
                ProductRequest request = ProductRequest.builder()
                                .name("  ")
                                .price(new BigDecimal("10.00"))
                                .build();

                mockMvc.perform(post("/api/v1/products")
                                .with(csrf())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(mapper.writeValueAsString(request)))
                                .andExpect(status().isBadRequest());
        }

        @Test
        @DisplayName("POST /products should return 401 when unauthenticated")
        void createProduct_shouldReturn401WhenUnauthenticated() throws Exception {
                ProductRequest request = ProductRequest.builder()
                                .name("Laptop")
                                .price(new BigDecimal("999.00"))
                                .build();

                mockMvc.perform(post("/api/v1/products")
                                .with(csrf())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(mapper.writeValueAsString(request)))
                                .andExpect(status().isUnauthorized());
        }

        // ── GET /api/v1/products/{id} ─────────────────────────────────────────────

        @Test
        @DisplayName("GET /products/{id} should return 200 with product JSON")
        void getProduct_shouldReturn200() throws Exception {
                UUID id = UUID.randomUUID();
                ProductDto dto = ProductDto.builder()
                                .id(id.toString())
                                .name("Gaming Laptop")
                                .price(new BigDecimal("1299.99"))
                                .stockQuantity(5)
                                .inStock(true)
                                .build();

                when(queryHandler.handle(any(GetProductQuery.class))).thenReturn(dto);

                mockMvc.perform(get("/api/v1/products/" + id))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.name").value("Gaming Laptop"))
                                .andExpect(jsonPath("$.inStock").value(true));
        }
}
