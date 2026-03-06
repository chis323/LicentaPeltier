package com.example.acpeltierbackend.web.controller;

import com.example.acpeltierbackend.service.HistoryService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
public class HistoryController {

    private final HistoryService history;

    public HistoryController(HistoryService history) {
        this.history = history;
    }

    @GetMapping("/api/history/daily")
    public Map<String, Object> daily(@RequestParam(name = "days", defaultValue = "7") int days) {
        var rows = history.getLastDays(days);
        DateTimeFormatter fmt = DateTimeFormatter.ISO_LOCAL_DATE;

        List<Map<String, Object>> out = rows.stream().map(r -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("day", (r.statDay == null ? null : r.statDay.format(fmt)));
            m.put("minAmbientTempC", r.minAmbientTempC);
            m.put("maxAmbientTempC", r.maxAmbientTempC);
            return m;
        }).toList();

        return Map.of("days", out);
    }
}