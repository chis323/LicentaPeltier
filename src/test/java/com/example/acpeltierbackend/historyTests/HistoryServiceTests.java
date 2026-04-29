package com.example.acpeltierbackend.historyTests;

import com.example.acpeltierbackend.entity.DailyAmbientStatsEntity;
import com.example.acpeltierbackend.repository.DailyAmbientStatRepo;
import com.example.acpeltierbackend.service.HistoryService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class HistoryServiceTests {

    @Mock
    private DailyAmbientStatRepo repo;

    @Test
    void recordAmbientSample_whenNull_doesNothing() {
        HistoryService service = new HistoryService(repo);

        service.recordAmbientSample(null, System.currentTimeMillis());

        verifyNoInteractions(repo);
    }

    @Test
    void recordAmbientSample_createsRowWhenMissing() {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        when(repo.findById(today)).thenReturn(Optional.empty());
        when(repo.findAll()).thenReturn(List.of());

        HistoryService service = new HistoryService(repo);

        service.recordAmbientSample(21.5, System.currentTimeMillis());

        verify(repo).save(argThat(row -> today.equals(row.statusDay) && row.minAmbientTempC.equals(21.5) && row.maxAmbientTempC.equals(21.5)));
    }

    @Test
    void recordAmbientSample_updatesMinAndMax() {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        DailyAmbientStatsEntity existing = new DailyAmbientStatsEntity();
        existing.statusDay = today;
        existing.minAmbientTempC = 20.0;
        existing.maxAmbientTempC = 30.0;

        when(repo.findById(today)).thenReturn(Optional.of(existing));
        when(repo.findAll()).thenReturn(List.of());

        HistoryService service = new HistoryService(repo);

        service.recordAmbientSample(10.0, System.currentTimeMillis());

        assertEquals(10.0, existing.minAmbientTempC);
        assertEquals(30.0, existing.maxAmbientTempC);
        verify(repo).save(existing);
    }

    @Test
    void purgeOlderThan7Days_deletesOldRows() {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);

        DailyAmbientStatsEntity old = new DailyAmbientStatsEntity();
        old.statusDay = today.minusDays(7);

        DailyAmbientStatsEntity recent = new DailyAmbientStatsEntity();
        recent.statusDay = today.minusDays(6);

        when(repo.findAll()).thenReturn(List.of(old, recent));

        HistoryService service = new HistoryService(repo);

        service.purgeOlderThan7Days();

        verify(repo).deleteById(old.statusDay);
        verify(repo, never()).deleteById(recent.statusDay);
    }

    @Test
    void getLastDays_clampsDaysAndFillsMissingRows() {
        when(repo.findById(any(LocalDate.class))).thenReturn(Optional.empty());

        HistoryService service = new HistoryService(repo);

        List<DailyAmbientStatsEntity> rows = service.getLastDays(50);

        assertEquals(30, rows.size());
        assertNotNull(rows.get(0).statusDay);
        assertNull(rows.get(0).minAmbientTempC);
        assertNull(rows.get(0).maxAmbientTempC);
    }
}
