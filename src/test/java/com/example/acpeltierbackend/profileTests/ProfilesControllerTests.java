package com.example.acpeltierbackend.profileTests;

import com.example.acpeltierbackend.service.ProfileService;
import com.example.acpeltierbackend.web.controller.ProfilesController;
import com.example.acpeltierbackend.web.dto.ProfileDtos;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ProfilesControllerTests {

    @Mock
    private ProfileService service;

    @Test
    void list_returnsProfilesMap() {
        ProfilesController controller = new ProfilesController(service);
        var summary = new ProfileDtos.ProfileSummary("p1", "Morning", true);

        when(service.listSummaries()).thenReturn(List.of(summary));

        Map<String, Object> result = controller.list();

        var profiles = (List<ProfileDtos.ProfileSummary>) result.get("profiles");
        assertEquals(1, profiles.size());
        assertEquals("p1", profiles.get(0).id());
        assertEquals("Morning", profiles.get(0).name());
        assertTrue(profiles.get(0).enabled());
    }

    @Test
    void get_returnsProfile() {
        ProfilesController controller = new ProfilesController(service);
        var profile = new ProfileDtos.Profile("p1", "Morning", false, List.of());

        when(service.get("p1")).thenReturn(profile);

        assertSame(profile, controller.get("p1"));
    }

    @Test
    void create_delegatesToService() {
        ProfilesController controller = new ProfilesController(service);
        var created = new ProfileDtos.Profile("p1", "Morning", false, List.of());

        when(service.create("Morning")).thenReturn(created);

        var result = controller.create(new ProfileDtos.CreateProfileReq("Morning"));

        assertSame(created, result);
    }

    @Test
    void save_delegatesToService() {
        ProfilesController controller = new ProfilesController(service);
        var incoming = new ProfileDtos.Profile("p1", "Night", true, List.of());
        var saved = new ProfileDtos.Profile("p1", "Night", true, List.of());

        when(service.save("p1", incoming)).thenReturn(saved);

        assertSame(saved, controller.save("p1", incoming));
    }

    @Test
    void enable_returnsOk() {
        ProfilesController controller = new ProfilesController(service);

        Map<String, Object> result = controller.enable("p1", new ProfileDtos.EnableReq(true));

        assertEquals(true, result.get("ok"));
        verify(service).setEnabled("p1", true);
    }

    @Test
    void delete_returnsOk() {
        ProfilesController controller = new ProfilesController(service);

        Map<String, Object> result = controller.delete("p1");

        assertEquals(true, result.get("ok"));
        verify(service).delete("p1");
    }
}
