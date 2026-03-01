package com.example.acpeltierbackend.db;

import jakarta.persistence.*;

import java.time.Instant;
import java.time.LocalDate;


@Entity
@Table(name = "daily_ambient_stats")
public class DailyAmbientStatsEntity {

    @Id
    @Column(name = "stat_day", nullable = false)
    public LocalDate statDay;

    @Column(name = "min_ambient_temp_c")
    public Double minAmbientTempC;

    @Column(name = "max_ambient_temp_c")
    public Double maxAmbientTempC;

    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt = Instant.now();
}