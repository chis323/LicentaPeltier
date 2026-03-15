package com.example.acpeltierbackend.security;
import com.example.acpeltierbackend.web.dto.Dtos;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketSession;

import java.util.concurrent.atomic.AtomicReference;

@Component
public class DeviceRegistry {
    private final AtomicReference<WebSocketSession> deviceSession = new AtomicReference<>();
    private final AtomicReference<Dtos.StatusResponse> latestStatus = new AtomicReference<>(new Dtos.StatusResponse());

    public void setSession(WebSocketSession session) { deviceSession.set(session); }
    public WebSocketSession getSession() { return deviceSession.get(); }
    public void clearSession() { deviceSession.set(null); }

    public boolean online() {
        WebSocketSession s = deviceSession.get();
        return s != null && s.isOpen();
    }

    public Dtos.StatusResponse getLatestStatus() {
        Dtos.StatusResponse s = latestStatus.get();
        s.deviceOnline = online();
        return s;
    }

    public void updateFromTelemetry(Dtos.TelemetryFrame t) {
        Dtos.StatusResponse s = new Dtos.StatusResponse();
        s.deviceOnline = online();
        s.ts = t.ts;

        s.ambientTempC = t.ambientTempC;
        s.humidityPct = t.humidityPct;

        s.hotSideTempC = t.hotSideTempC;
        s.coldSideTempC = t.coldSideTempC;

        s.coldFanPwm = t.coldFanPwm;
        s.hotFanPwm = t.hotFanPwm;
        s.peltierOn = t.peltierOn;

        s.swingOn = t.swingOn;
        s.fault = t.fault;

        latestStatus.set(s);
    }
}
