package com.example.acpeltierbackend;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.socket.TextMessage;

@RestController
public class ApiController {

    private final DeviceRegistry reg;
    private final ObjectMapper om = new ObjectMapper();

    public ApiController(DeviceRegistry reg) {
        this.reg = reg;
    }

    @PostMapping("/api/command")
    public ResponseEntity<?> command(@Valid @RequestBody Dtos.CommandRequest req) throws Exception {
        if (!reg.online()) {
            return ResponseEntity.status(409).body(java.util.Map.of("error", "DEVICE_OFFLINE"));
        }

        var payload = om.valueToTree(req);

        var msg = om.createObjectNode();
        msg.put("type", "command");
        msg.set("payload", payload);

        reg.getSession().sendMessage(new TextMessage(om.writeValueAsString(msg)));
        return ResponseEntity.ok(java.util.Map.of("sent", true));
    }


    @GetMapping("/api/status")
    public Dtos.StatusResponse status() {
        return reg.getLatestStatus();
    }

    @GetMapping("/health")
    public java.util.Map<String, Object> health() {
        return java.util.Map.of("ok", true, "deviceOnline", reg.online());
    }
}
