package com.example.acpeltierbackend.entity;

import jakarta.persistence.*;
import java.time.LocalDate;


@Entity
@Table(name = "daily_ambient_stats")
public class DailyAmbientStatsEntity {
    @Id
    @Column(name = "stat_day", nullable = false)
    public LocalDate statusDay;

    @Column(name = "min_ambient_temp")
    public Double minAmbientTempC;

    @Column(name = "max_ambient_temp")
    public Double maxAmbientTempC;
}