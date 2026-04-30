package com.example.acpeltierbackend.profileTests;

import com.example.acpeltierbackend.entity.ProfileEntity;
import com.example.acpeltierbackend.service.CommandSenderService;
import com.example.acpeltierbackend.service.ProfileSchedulerService;
import com.example.acpeltierbackend.service.ProfileService;
import com.example.acpeltierbackend.web.dto.CommandRequestDto;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.ArrayList;
import java.util.Optional;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ProfileSchedulerServiceTests {

    @Mock
    private ProfileService profileService;

    @Mock
    private CommandSenderService sender;

    @Test
    void tick_whenNoEnabledProfile_sendsIdleCommand() {
        when(profileService.getEnabledProfileEntity()).thenReturn(Optional.empty());
        when(sender.sendCommand(any())).thenReturn(true);

        ProfileSchedulerService service = new ProfileSchedulerService(profileService, sender);

        service.tick();

        verify(sender).sendCommand(argThat(payload -> {
            CommandRequestDto cmd = (CommandRequestDto) payload;
            return cmd.coldFanPwm == 0 && cmd.hotFanPwm == 0 && Boolean.FALSE.equals(cmd.peltierOn) && Boolean.FALSE.equals(cmd.swingOn);
        }));
    }

    @Test
    void tick_whenSameIdleAlreadyApplied_doesNotSendAgain() {
        when(profileService.getEnabledProfileEntity()).thenReturn(Optional.empty());
        when(sender.sendCommand(any())).thenReturn(true);

        ProfileSchedulerService service = new ProfileSchedulerService(profileService, sender);

        service.tick();
        service.tick();

        verify(sender, times(1)).sendCommand(any());
    }

    @Test
    void tick_whenEnabledProfileHasNoRules_sendsIdleCommand() {
        ProfileEntity profile = new ProfileEntity();
        profile.id = UUID.randomUUID();
        profile.name = "Empty";
        profile.enabled = true;
        profile.rules = new ArrayList<>();

        when(profileService.getEnabledProfileEntity()).thenReturn(Optional.of(profile));
        when(sender.sendCommand(any())).thenReturn(true);

        ProfileSchedulerService service = new ProfileSchedulerService(profileService, sender);

        service.tick();

        verify(sender).sendCommand(argThat(payload -> {
            CommandRequestDto cmd = (CommandRequestDto) payload;
            return cmd.coldFanPwm == 0 && cmd.hotFanPwm == 0;
        }));
    }

    @Test
    void tick_whenServiceThrows_catchesException() {
        when(profileService.getEnabledProfileEntity()).thenThrow(new RuntimeException("boom"));

        ProfileSchedulerService service = new ProfileSchedulerService(profileService, sender);

        service.tick();

        verifyNoInteractions(sender);
    }
}
