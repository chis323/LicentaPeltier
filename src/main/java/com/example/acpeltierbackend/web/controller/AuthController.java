package com.example.acpeltierbackend.web.controller;

import com.example.acpeltierbackend.security.AppConfig;
import com.example.acpeltierbackend.security.JwtService;
import com.example.acpeltierbackend.web.dto.LoginRequestDto;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Arrays;
import java.util.Map;

@RestController
@RequestMapping("/auth")
public class AuthController {
    private final AppConfig cfg;
    private final JwtService jwtService;

    public AuthController(AppConfig cfg, JwtService jwtService) {
        this.cfg = cfg;
        this.jwtService = jwtService;
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequestDto req) {
        if (req == null || !isValidUser(req.username(), req.password())) {
            return ResponseEntity.status(401).body(Map.of("error", "INVALID_CREDENTIALS"));
        }
        String token = jwtService.generateToken(req.username());
        return ResponseEntity.ok(Map.of("token", token, "tokenType", "Bearer"));
    }

    private boolean isValidUser(String username, String password) {
        if (username == null || password == null) {
            return false;
        }

        return Arrays.stream(cfg.authUsers.split(",")).map(String::trim).filter(entry -> !entry.isBlank()).anyMatch(entry -> {
            String[] parts = entry.split(":", 2);
            return parts.length == 2 && parts[0].equals(username) && parts[1].equals(password);
        });
    }
}