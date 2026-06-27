package com.example.acpeltierbackend.security;

import com.example.acpeltierbackend.web.dto.StatusResponseDto;
import com.example.acpeltierbackend.web.dto.TelemetryFrameDto;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketSession;

import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

@Component
public class DeviceRegistry {
    private static final long OFFLINE_TIMEOUT_MS = 10_000;

    private final AtomicReference<WebSocketSession> deviceSession = new AtomicReference<>();
    private final AtomicLong lastTelemetryMs = new AtomicLong(0);

    private final AtomicReference<StatusResponseDto> latestStatus = new AtomicReference<>(emptyStatus());

    public void setSession(WebSocketSession session) {
        deviceSession.set(session);
    }

    public WebSocketSession getSession() {
        return deviceSession.get();
    }

    public void clearSession(WebSocketSession session) {
        deviceSession.compareAndSet(session, null);
    }

    public void markTelemetrySeen() {
        lastTelemetryMs.set(System.currentTimeMillis());
    }

    public boolean online() {
        WebSocketSession s = deviceSession.get();
        if (s == null || !s.isOpen()) {
            return false;
        }
        return System.currentTimeMillis() - lastTelemetryMs.get() < OFFLINE_TIMEOUT_MS;
    }

    public StatusResponseDto getLatestStatus() {
        StatusResponseDto s = latestStatus.get();
        return new StatusResponseDto(online(), s.ts(), s.ambientTempC(), s.humidityPct(), s.coldFanPwm(), s.hotFanPwm(), s.peltierOn(), s.swingOn());
    }

    public void updateFromTelemetry(TelemetryFrameDto t) {
        markTelemetrySeen();
        StatusResponseDto s = new StatusResponseDto(online(), t.ts(), t.ambientTempC(), t.humidityPct(), t.coldFanPwm(), t.hotFanPwm(), t.peltierOn(), t.swingOn());
        latestStatus.set(s);
    }

    private static StatusResponseDto emptyStatus() {
        return new StatusResponseDto(false, null, null, null, null, null, null, null);
    }
}