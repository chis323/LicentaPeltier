package com.example.acpeltierbackend.profileTests;

import com.example.acpeltierbackend.entity.ProfileEntity;
import com.example.acpeltierbackend.entity.ProfileRuleEntity;
import com.example.acpeltierbackend.repository.ProfileRepo;
import com.example.acpeltierbackend.service.ProfileService;
import com.example.acpeltierbackend.web.dto.ProfileDtos;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ProfileServiceTests {

    @Mock
    private ProfileRepo repo;

    @Test
    void listSummaries_returnsSortedSummaries() {
        ProfileEntity b = profile("Beta", false);
        ProfileEntity a = profile("Alpha", true);

        when(repo.findAll()).thenReturn(List.of(b, a));

        ProfileService service = new ProfileService(repo);

        List<ProfileDtos.ProfileSummary> result = service.listSummaries();

        assertEquals(2, result.size());
        assertEquals("Alpha", result.get(0).name());
        assertTrue(result.get(0).enabled());
        assertEquals("Beta", result.get(1).name());
    }

    @Test
    void create_savesNewProfile() {
        when(repo.count()).thenReturn(0L);
        when(repo.save(any(ProfileEntity.class))).thenAnswer(invocation -> invocation.getArgument(0));

        ProfileService service = new ProfileService(repo);

        ProfileDtos.Profile result = service.create("  Morning  ");

        assertNotNull(result.id());
        assertEquals("Morning", result.name());
        assertFalse(result.enabled());
        assertTrue(result.rules().isEmpty());
    }

    @Test
    void create_whenMaxProfiles_throwsException() {
        when(repo.count()).thenReturn(3L);

        ProfileService service = new ProfileService(repo);

        IllegalStateException ex = assertThrows(IllegalStateException.class, () -> service.create("Extra"));
        assertEquals("Maximum 3 profiles allowed", ex.getMessage());
    }

    @Test
    void get_returnsProfileWithSortedRules() {
        ProfileEntity p = profile("Morning", true);

        ProfileRuleEntity late = rule(p, 2, "12:00", "13:00");
        ProfileRuleEntity early = rule(p, 1, "08:00", "09:00");
        p.rules.add(late);
        p.rules.add(early);

        when(repo.findById(p.id)).thenReturn(Optional.of(p));

        ProfileService service = new ProfileService(repo);

        ProfileDtos.Profile result = service.get(p.id.toString());

        assertEquals(p.id.toString(), result.id());
        assertEquals("Morning", result.name());
        assertEquals(2, result.rules().size());
        assertEquals(1, result.rules().get(0).dayOfWeek());
        assertEquals(2, result.rules().get(1).dayOfWeek());
    }

    @Test
    void get_whenMissing_throwsException() {
        UUID id = UUID.randomUUID();
        when(repo.findById(id)).thenReturn(Optional.empty());

        ProfileService service = new ProfileService(repo);

        assertThrows(NoSuchElementException.class, () -> service.get(id.toString()));
    }

    @Test
    void save_updatesProfileAndClampsRuleValues() {
        ProfileEntity existing = profile("Old", false);
        when(repo.findById(existing.id)).thenReturn(Optional.of(existing));
        when(repo.save(any(ProfileEntity.class))).thenAnswer(invocation -> invocation.getArgument(0));

        ProfileDtos.Rule rule = new ProfileDtos.Rule(null, 99, "bad-time", "22:30", -5, 150, true, false);
        ProfileDtos.Profile incoming = new ProfileDtos.Profile(existing.id.toString(), "  New  ", true, List.of(rule));

        ProfileService service = new ProfileService(repo);

        ProfileDtos.Profile result = service.save(existing.id.toString(), incoming);

        assertEquals("New", result.name());
        assertTrue(result.enabled());
        assertEquals(1, result.rules().size());
        assertEquals(7, result.rules().get(0).dayOfWeek());
        assertEquals("08:00", result.rules().get(0).start());
        assertEquals("22:30", result.rules().get(0).end());
        assertEquals(0, result.rules().get(0).coldFanPwm());
        assertEquals(100, result.rules().get(0).hotFanPwm());
    }

    @Test
    void delete_disablesEnabledProfileBeforeDeleting() {
        ProfileEntity p = profile("Morning", true);
        when(repo.findById(p.id)).thenReturn(Optional.of(p));

        ProfileService service = new ProfileService(repo);

        service.delete(p.id.toString());

        assertFalse(p.enabled);
        verify(repo).save(p);
        verify(repo).deleteById(p.id);
    }

    @Test
    void setEnabled_true_enablesOnlySelectedProfile() {
        ProfileEntity selected = profile("Selected", false);
        ProfileEntity other = profile("Other", true);
        when(repo.findAll()).thenReturn(List.of(selected, other));

        ProfileService service = new ProfileService(repo);

        service.setEnabled(selected.id.toString(), true);

        assertTrue(selected.enabled);
        assertFalse(other.enabled);
        verify(repo).saveAll(List.of(selected, other));
    }

    @Test
    void setEnabled_false_disablesProfile() {
        ProfileEntity p = profile("Morning", true);
        when(repo.findById(p.id)).thenReturn(Optional.of(p));

        ProfileService service = new ProfileService(repo);

        service.setEnabled(p.id.toString(), false);

        assertFalse(p.enabled);
        verify(repo).save(p);
    }

    @Test
    void getEnabledProfileEntity_returnsFirstEnabledProfile() {
        ProfileEntity p = profile("Enabled", true);
        when(repo.findByEnabledTrue()).thenReturn(List.of(p));

        ProfileService service = new ProfileService(repo);

        assertEquals(Optional.of(p), service.getEnabledProfileEntity());
    }

    private static ProfileEntity profile(String name, boolean enabled) {
        ProfileEntity p = new ProfileEntity();
        p.id = UUID.randomUUID();
        p.name = name;
        p.enabled = enabled;
        p.rules = new ArrayList<>();
        return p;
    }

    private static ProfileRuleEntity rule(ProfileEntity p, int dayOfWeek, String start, String end) {
        ProfileRuleEntity r = new ProfileRuleEntity();
        r.id = UUID.randomUUID();
        r.profile = p;
        r.dayOfWeek = dayOfWeek;
        r.startTime = LocalTime.parse(start);
        r.endTime = LocalTime.parse(end);
        r.coldFanPwm = 10;
        r.hotFanPwm = 20;
        r.peltierOn = true;
        r.swingOn = false;
        return r;
    }
}
