package com.example.acpeltierbackend.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class AppConfig {
    public final String deviceKey;
    public final String authUsers;
    public final String jwtSecret;
    public final long jwtExpirationMs;

    public AppConfig(
            @Value("${app.deviceKey:${APP_DEVICEKEY:CHANGE_ME_DEVICE_KEY}}") String deviceKey,
            @Value("${app.auth.users:${APP_AUTH_USERS:admin:admin}}") String authUsers,
            @Value("${app.jwt.secret:${APP_JWT_SECRET:this-is-a-production-secret-change-it-to-a-long-random-value}}") String jwtSecret,
            @Value("${app.jwt.expirationMs:${APP_JWT_EXPIRATION_MS:86400000}}") long jwtExpirationMs
    ) {
        this.deviceKey = deviceKey;
        this.authUsers = authUsers;
        this.jwtSecret = jwtSecret;
        this.jwtExpirationMs = jwtExpirationMs;
    }
}