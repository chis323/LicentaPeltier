package com.example.acpeltierbackend.db;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;

public interface DailyAmbientStatRepo extends JpaRepository<DailyAmbientStatsEntity, LocalDate> {
}
