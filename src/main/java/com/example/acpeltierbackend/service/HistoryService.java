package com.example.acpeltierbackend.service;

import com.example.acpeltierbackend.repository.DailyAmbientStatRepo;
import com.example.acpeltierbackend.entity.DailyAmbientStatsEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

@Service
public class HistoryService {

    private final DailyAmbientStatRepo repo;

    public HistoryService(DailyAmbientStatRepo repo) {
        this.repo = repo;
    }
    private LocalDate todayUtc() {
        return LocalDate.now(ZoneOffset.UTC);
    }

    @Transactional
    public void recordAmbientSample(Double ambientTempC) {
        if (ambientTempC == null) return;

        LocalDate day = todayUtc();

        DailyAmbientStatsEntity e = repo.findById(day).orElseGet(() -> {
            DailyAmbientStatsEntity n = new DailyAmbientStatsEntity();
            n.statusDay = day;
            n.minAmbientTempC = ambientTempC;
            n.maxAmbientTempC = ambientTempC;
            return n;
        });

        if (e.minAmbientTempC == null || ambientTempC < e.minAmbientTempC) e.minAmbientTempC = ambientTempC;
        if (e.maxAmbientTempC == null || ambientTempC > e.maxAmbientTempC) e.maxAmbientTempC = ambientTempC;

        repo.save(e);

        purgeOlderThan7Days();
    }

    @Transactional
    public void purgeOlderThan7Days() {
        LocalDate cutoff = todayUtc().minusDays(6);
        repo.findAll().forEach(row -> {
            if (row.statusDay != null && row.statusDay.isBefore(cutoff)) {
                repo.deleteById(row.statusDay);
            }
        });
    }

    @Transactional(readOnly = true)
    public List<DailyAmbientStatsEntity> getLast7Days() {
        LocalDate start = todayUtc().minusDays(6);

        List<DailyAmbientStatsEntity> rows = new ArrayList<>();

        for (int i = 0; i < 7; i++) {
            LocalDate day = start.plusDays(i);

            DailyAmbientStatsEntity row = repo.findById(day)
                    .orElseGet(() -> emptyRow(day));

            rows.add(row);
        }
        return rows;
    }

    private static DailyAmbientStatsEntity emptyRow(LocalDate day) {
        DailyAmbientStatsEntity row = new DailyAmbientStatsEntity();
        row.statusDay = day;
        row.minAmbientTempC = null;
        row.maxAmbientTempC = null;
        return row;
    }
}