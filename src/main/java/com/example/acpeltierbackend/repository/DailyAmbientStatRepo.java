package com.example.acpeltierbackend.repository;

import com.example.acpeltierbackend.entity.DailyAmbientStatsEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;

public interface DailyAmbientStatRepo extends JpaRepository<DailyAmbientStatsEntity, LocalDate> {
}
