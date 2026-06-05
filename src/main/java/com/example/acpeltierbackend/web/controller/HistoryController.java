package com.example.acpeltierbackend.web.controller;

import com.example.acpeltierbackend.service.HistoryService;
import com.example.acpeltierbackend.web.dto.DailyHistoryDto;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
public class HistoryController {

    private final HistoryService history;

    public HistoryController(HistoryService history) {
        this.history = history;
    }

    @GetMapping("/api/history/daily")
    public Map<String, List<DailyHistoryDto>> daily() {
        List<DailyHistoryDto> rows = history.getLast7Days()
                .stream()
                .map(row -> new DailyHistoryDto(
                        row.statusDay,
                        row.minAmbientTempC,
                        row.maxAmbientTempC
                ))
                .toList();
        return Map.of("days", rows);
    }
}