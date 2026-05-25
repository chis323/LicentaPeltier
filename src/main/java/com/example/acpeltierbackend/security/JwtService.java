package com.example.acpeltierbackend.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Date;

@Service
public class JwtService {
    private final AppConfig cfg;
    private final SecretKey key;

    public JwtService(AppConfig cfg) {
        this.cfg = cfg;
        this.key = Keys.hmacShaKeyFor(sha256(cfg.jwtSecret));
    }

    public String generateToken(String username) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + cfg.jwtExpirationMs);

        return Jwts.builder().subject(username).issuedAt(now).expiration(expiry).signWith(key).compact();
    }

    public String validateAndGetUsername(String token) {
        Claims claims = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();

        return claims.getSubject();
    }

    private byte[] sha256(String value) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new IllegalStateException("Could not create JWT signing key", e);
        }
    }
}
