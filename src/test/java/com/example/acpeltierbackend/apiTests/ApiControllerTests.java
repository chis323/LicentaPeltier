package com.example.acpeltierbackend.apiTests;

import com.example.acpeltierbackend.security.DeviceRegistry;
import com.example.acpeltierbackend.web.controller.ApiController;
import com.example.acpeltierbackend.web.dto.CommandRequestDto;
import com.example.acpeltierbackend.web.dto.StatusResponseDto;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ApiControllerTests {

    @Mock
    private DeviceRegistry reg;

    @Mock
    private WebSocketSession session;

    @Test
    void health_returnsOkAndDeviceOnline() {
        when(reg.online()).thenReturn(true);

        ApiController controller = new ApiController(reg);

        var result = controller.health();

        assertEquals(true, result.get("ok"));
        assertEquals(true, result.get("deviceOnline"));
    }

    @Test
    void status_returnsLatestStatus() {
        StatusResponseDto status = new StatusResponseDto();
        status.deviceOnline = true;
        status.ambientTempC = 22.5;

        when(reg.getLatestStatus()).thenReturn(status);

        ApiController controller = new ApiController(reg);

        assertSame(status, controller.status());
    }

    @Test
    void command_offline_returns409() throws Exception {
        when(reg.online()).thenReturn(false);

        ApiController controller = new ApiController(reg);

        CommandRequestDto req = new CommandRequestDto();
        req.coldFanPwm = 50;
        req.hotFanPwm = 60;
        req.peltierOn = true;
        req.swingOn = false;

        var response = controller.command(req);

        assertEquals(HttpStatus.CONFLICT, response.getStatusCode());
        assertEquals("{error=DEVICE_OFFLINE}", response.getBody().toString());
        verify(reg, never()).getSession();
    }

    @Test
    void command_online_sendsMessage() throws Exception {
        when(reg.online()).thenReturn(true);
        when(reg.getSession()).thenReturn(session);

        ApiController controller = new ApiController(reg);

        CommandRequestDto req = new CommandRequestDto();
        req.coldFanPwm = 50;
        req.hotFanPwm = 60;
        req.peltierOn = true;
        req.swingOn = false;

        var response = controller.command(req);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("{sent=true}", response.getBody().toString());

        verify(session).sendMessage(argThat(message -> {
            String payload = ((TextMessage) message).getPayload();
            return payload.contains("\"type\":\"command\"") && payload.contains("\"coldFanPwm\":50") && payload.contains("\"hotFanPwm\":60") && payload.contains("\"peltierOn\":true") && payload.contains("\"swingOn\":false");
        }));
    }
}
