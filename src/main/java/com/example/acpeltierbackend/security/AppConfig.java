package com.example.acpeltierbackend.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class AppConfig {
    public final String apiKey;
    public final String deviceKey;

    public AppConfig(@Value("${app.apiKey}") String apiKey,
                     @Value("${app.deviceKey}") String deviceKey) {
        this.apiKey = apiKey;
        this.deviceKey = deviceKey;
    }
}
