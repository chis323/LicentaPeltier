package com.example.acpeltierbackend.apiTests;

import com.example.acpeltierbackend.security.DeviceRegistry;
import com.example.acpeltierbackend.service.CommandSenderService;
import com.example.acpeltierbackend.web.dto.CommandRequestDto;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CommandSenderServiceTests {

    @Mock
    private DeviceRegistry reg;

    @Mock
    private WebSocketSession session;

    @Test
    void sendCommand_whenOffline_returnsFalse() {
        when(reg.online()).thenReturn(false);

        CommandSenderService service = new CommandSenderService(reg);

        CommandRequestDto req = new CommandRequestDto(
                false,
                0,
                0,
                false
        );
        assertFalse(service.sendCommand(req));
        verify(reg, never()).getSession();
    }

    @Test
    void sendCommand_whenOnline_sendsMessageAndReturnsTrue() throws Exception {
        when(reg.online()).thenReturn(true);
        when(reg.getSession()).thenReturn(session);

        CommandRequestDto req = new CommandRequestDto(
                false,
                25,
                75,
                true
        );

        CommandSenderService service = new CommandSenderService(reg);

        assertTrue(service.sendCommand(req));

        verify(session).sendMessage(argThat(message -> {
            String payload = ((TextMessage) message).getPayload();
            return payload.contains("\"type\":\"command\"") && payload.contains("\"coldFanPwm\":25") && payload.contains("\"hotFanPwm\":75");
        }));
    }
}
