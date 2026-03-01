package com.example.acpeltierbackend.db;

import jakarta.persistence.*;

import java.time.LocalTime;
import java.util.UUID;

@Entity
@Table(name = "profile_rules")
public class ProfileRuleEntity {

    @Id
    @Column(name = "id", nullable = false)
    public UUID id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "profile_id", nullable = false)
    public ProfileEntity profile;

    @Column(name = "day_of_week", nullable = false)
    public int dayOfWeek;

    @Column(name = "start_time", nullable = false)
    public LocalTime startTime;

    @Column(name = "end_time", nullable = false)
    public LocalTime endTime;

    @Column(name = "cold_fan_pwm", nullable = false)
    public int coldFanPwm;

    @Column(name = "hot_fan_pwm", nullable = false)
    public int hotFanPwm;

    @Column(name = "peltier_on", nullable = false)
    public boolean peltierOn;

    @Column(name = "swing_on", nullable = false)
    public boolean swingOn;
}
