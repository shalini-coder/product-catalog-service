package com.example.productcatalog.api.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Lightweight liveness probe endpoint (separate from Spring Actuator).
 */
@RestController
@RequestMapping("/api/v1")
@Tag(name = "Health", description = "Service liveness checks")
public class HealthController {

    @GetMapping("/health")
    @Operation(summary = "Liveness probe")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("status", "UP"));
    }
}
