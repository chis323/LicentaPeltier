package com.example.acpeltierbackend.security;

import com.example.acpeltierbackend.web.dto.StatusResponseDto;
import com.example.acpeltierbackend.web.dto.TelemetryFrameDto;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketSession;

import java.util.concurrent.atomic.AtomicReference;

@Component
public class DeviceRegistry {
    private final AtomicReference<WebSocketSession> deviceSession = new AtomicReference<>();
    private final AtomicReference<StatusResponseDto> latestStatus = new AtomicReference<>(new StatusResponseDto());

    public void setSession(WebSocketSession session) {
        deviceSession.set(session);
    }

    public WebSocketSession getSession() {
        return deviceSession.get();
    }

    public void clearSession() {
        deviceSession.set(null);
    }

    public boolean online() {
        WebSocketSession s = deviceSession.get();
        return s != null && s.isOpen();
    }

    public StatusResponseDto getLatestStatus() {
        StatusResponseDto s = latestStatus.get();
        s.deviceOnline = online();
        return s;
    }

    public void updateFromTelemetry(TelemetryFrameDto t) {
        StatusResponseDto s = new StatusResponseDto();
        s.deviceOnline = online();
        s.ts = t.ts;
        s.ambientTempC = t.ambientTempC;
        s.humidityPct = t.humidityPct;
        s.coldFanPwm = t.coldFanPwm;
        s.hotFanPwm = t.hotFanPwm;
        s.peltierOn = t.peltierOn;
        s.swingOn = t.swingOn;
        latestStatus.set(s);
    }
}
