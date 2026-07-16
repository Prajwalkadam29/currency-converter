package com.currencyapp.converter;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class HealthCheckController {

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> healthCheck() {
        // Kubernetes strictly looks for a 200-399 HTTP status code to pass the probe.
        // Returning a JSON body isn't strictly necessary for K8s, but it is standard
        // practice for general observability and debugging.
        return ResponseEntity.ok(Map.of("status", "UP"));
    }
}