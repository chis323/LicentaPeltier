package com.example.acpeltierbackend.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class AppConfig {
    public final String apiKey;
    public final String deviceKey;
    public final String authUsername;
    public final String authPassword;
    public final String jwtSecret;
    public final long jwtExpirationMs;

    public AppConfig(
            @Value("${app.apiKey:${APP_APIKEY:}}") String apiKey,
            @Value("${app.deviceKey:${APP_DEVICEKEY:CHANGE_ME_DEVICE_KEY}}") String deviceKey,
            @Value("${app.auth.username:${APP_AUTH_USERNAME:admin}}") String authUsername,
            @Value("${app.auth.password:${APP_AUTH_PASSWORD:admin}}") String authPassword,
            @Value("${app.jwt.secret:${APP_JWT_SECRET:this-is-a-local-dev-secret-change-it-in-production-123456789}}") String jwtSecret,
            @Value("${app.jwt.expirationMs:${APP_JWT_EXPIRATION_MS:86400000}}") long jwtExpirationMs
    ) {
        this.apiKey = apiKey;
        this.deviceKey = deviceKey;
        this.authUsername = authUsername;
        this.authPassword = authPassword;
        this.jwtSecret = jwtSecret;
        this.jwtExpirationMs = jwtExpirationMs;
    }
}