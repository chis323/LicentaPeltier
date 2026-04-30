package com.example.acpeltierbackend.security;

import com.example.acpeltierbackend.web.dto.TelemetryFrameDto;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.net.URI;
import java.util.Optional;

@Component
public class DeviceWsHandler extends TextWebSocketHandler {

    private final AppConfig cfg;
    private final DeviceRegistry reg;
    private final com.example.acpeltierbackend.service.HistoryService history;
    private final ObjectMapper om = new ObjectMapper();

    public DeviceWsHandler(AppConfig cfg, DeviceRegistry reg, com.example.acpeltierbackend.service.HistoryService history) {
        this.cfg = cfg;
        this.reg = reg;
        this.history = history;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        String key = getQueryParam(session.getUri(), "key").orElseThrow(() -> new IllegalArgumentException("Missing key"));

        if (!cfg.deviceKey.equals(key)) {
            session.close(CloseStatus.NOT_ACCEPTABLE.withReason("Bad device key"));
            return;
        }

        reg.setSession(session);
        session.sendMessage(new TextMessage("{\"type\":\"hello\",\"ok\":true}"));
    }

    @Override
    protected void handleTextMessage(@NonNull WebSocketSession session, TextMessage message) throws Exception {
        var root = om.readTree(message.getPayload());
        String type = root.path("type").asText("");

        if ("telemetry".equals(type)) {
            TelemetryFrameDto t = om.treeToValue(root, TelemetryFrameDto.class);
            if (t.ts == null) t.ts = System.currentTimeMillis();
            reg.updateFromTelemetry(t);
            try {
                history.recordAmbientSample(t.ambientTempC, t.ts);
            } catch (Exception e) {
                System.out.println("[DB] history write failed: " + e.getMessage());
            }
            return;
        }

        if ("log".equals(type)) {
            System.out.println("PI LOG: " + root.path("message").asText(""));
        }
    }

    @Override
    public void afterConnectionClosed(@NonNull WebSocketSession session, @NonNull CloseStatus status) {
        reg.clearSession();
    }

    private Optional<String> getQueryParam(URI uri, String name) {
        if (uri == null || uri.getQuery() == null) return Optional.empty();
        for (String p : uri.getQuery().split("&")) {
            String[] kv = p.split("=", 2);
            if (kv.length == 2 && kv[0].equals(name)) return Optional.of(kv[1]);
        }
        return Optional.empty();
    }
}
