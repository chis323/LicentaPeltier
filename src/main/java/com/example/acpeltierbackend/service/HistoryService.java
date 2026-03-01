package com.example.acpeltierbackend.service;

import com.example.acpeltierbackend.db.DailyAmbientStatRepo;
import com.example.acpeltierbackend.db.DailyAmbientStatsEntity;
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
    public void recordAmbientSample(Double ambientTempC, long tsMillis) {
        if (ambientTempC == null) return;

        LocalDate day = todayUtc();

        DailyAmbientStatsEntity e = repo.findById(day).orElseGet(() -> {
            DailyAmbientStatsEntity n = new DailyAmbientStatsEntity();
            n.statDay = day;
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
            if (row.statDay != null && row.statDay.isBefore(cutoff)) {
                repo.deleteById(row.statDay);
            }
        });
    }

    @Transactional(readOnly = true)
    public List<DailyAmbientStatsEntity> getLastDays(int days) {
        int n = Math.max(1, Math.min(days, 30));
        LocalDate end = todayUtc();
        LocalDate start = end.minusDays(n - 1L);

        List<DailyAmbientStatsEntity> out = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            LocalDate d = start.plusDays(i);

            DailyAmbientStatsEntity row = repo.findById(d).orElseGet(() -> {
                DailyAmbientStatsEntity empty = new DailyAmbientStatsEntity();
                empty.statDay = d;
                empty.minAmbientTempC = null;
                empty.maxAmbientTempC = null;
                return empty;
            });

            out.add(row);
        }
        return out;
    }
}