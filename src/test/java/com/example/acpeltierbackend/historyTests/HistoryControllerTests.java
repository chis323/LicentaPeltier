package com.example.acpeltierbackend.historyTests;

import com.example.acpeltierbackend.entity.DailyAmbientStatsEntity;
import com.example.acpeltierbackend.service.HistoryService;
import com.example.acpeltierbackend.web.controller.HistoryController;
import com.example.acpeltierbackend.web.dto.DailyHistoryDto;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class HistoryControllerTests {

    @Mock
    private HistoryService history;

    @Test
    void daily_returnsMappedData() {
        HistoryController controller = new HistoryController(history);
        DailyAmbientStatsEntity row = new DailyAmbientStatsEntity();

        row.statusDay = LocalDate.of(2026, 4, 29);
        row.minAmbientTempC = 10.0;
        row.maxAmbientTempC = 20.0;
        when(history.getLast7Days()).thenReturn(List.of(row));
        Map<String, List<DailyHistoryDto>> result = controller.daily();
        List<DailyHistoryDto> days = result.get("days");
        assertEquals(1, days.size());
        assertEquals(LocalDate.of(2026, 4, 29), days.get(0).day());
        assertEquals(10.0, days.get(0).minAmbientTempC());
        assertEquals(20.0, days.get(0).maxAmbientTempC());
    }

    @Test
    void daily_handlesNullDate() {
        HistoryController controller = new HistoryController(history);
        DailyAmbientStatsEntity row = new DailyAmbientStatsEntity();

        row.statusDay = null;
        row.minAmbientTempC = 5.0;
        row.maxAmbientTempC = 15.0;
        when(history.getLast7Days()).thenReturn(List.of(row));
        Map<String, List<DailyHistoryDto>> result = controller.daily();
        List<DailyHistoryDto> days = result.get("days");
        assertNull(days.get(0).day());
        assertEquals(5.0, days.get(0).minAmbientTempC());
        assertEquals(15.0, days.get(0).maxAmbientTempC());
    }
}
