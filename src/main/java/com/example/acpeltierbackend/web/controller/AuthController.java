package com.example.acpeltierbackend.web.controller;

import com.example.acpeltierbackend.security.AppConfig;
import com.example.acpeltierbackend.security.JwtService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class AuthController {
    private final AppConfig cfg;
    private final JwtService jwtService;

    public AuthController(AppConfig cfg, JwtService jwtService) {
        this.cfg = cfg;
        this.jwtService = jwtService;
    }

    @PostMapping("/auth/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest req) {
        if (req == null || req.username() == null || req.password() == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "MISSING_CREDENTIALS"));
        }

        boolean valid = cfg.authUsername.equals(req.username()) && cfg.authPassword.equals(req.password());
        if (!valid) {
            return ResponseEntity.status(401).body(Map.of("error", "INVALID_CREDENTIALS"));
        }

        String token = jwtService.generateToken(req.username());
        return ResponseEntity.ok(Map.of("token", token, "tokenType", "Bearer"));
    }

    public record LoginRequest(String username, String password) {
    }
}
