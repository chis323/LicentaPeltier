package com.example.acpeltierbackend.service;

import com.example.acpeltierbackend.security.DeviceRegistry;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;
import org.springframework.web.socket.TextMessage;

@Service
public class CommandSenderService {

    private final DeviceRegistry reg;
    private final ObjectMapper om = new ObjectMapper();

    public CommandSenderService(DeviceRegistry reg) {
        this.reg = reg;
    }

    public boolean sendCommand(Object payloadPojo) {
        if (!reg.online()) return false;
        try {
            var payload = om.valueToTree(payloadPojo);
            var msg = om.createObjectNode();
            msg.put("type", "command");
            msg.set("payload", payload);
            reg.getSession().sendMessage(new TextMessage(om.writeValueAsString(msg)));
            return true;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
