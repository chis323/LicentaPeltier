package com.example.acpeltierbackend.mapper;

import com.example.acpeltierbackend.entity.ProfileEntity;
import com.example.acpeltierbackend.entity.ProfileRuleEntity;
import com.example.acpeltierbackend.web.dto.ProfileDtos;

import java.time.LocalTime;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

public final class ProfileMapper {

    private ProfileMapper() {
    }

    public static ProfileDtos.ProfileSummary toSummary(ProfileEntity profile) {
        return new ProfileDtos.ProfileSummary(
                profile.id.toString(),
                profile.name,
                profile.enabled
        );
    }

    public static ProfileDtos.Profile toProfile(ProfileEntity profile) {
        List<ProfileDtos.Rule> rules = profile.rules.stream()
                .sorted(Comparator
                        .comparingInt((ProfileRuleEntity rule) -> rule.dayOfWeek)
                        .thenComparing(rule -> rule.startTime))
                .map(ProfileMapper::toRule)
                .toList();

        return new ProfileDtos.Profile(
                profile.id.toString(),
                profile.name,
                profile.enabled,
                rules
        );
    }

    public static ProfileDtos.Rule toRule(ProfileRuleEntity rule) {
        return new ProfileDtos.Rule(
                rule.id.toString(),
                rule.dayOfWeek,
                rule.startTime.toString(),
                rule.endTime.toString(),
                rule.coldFanPwm,
                rule.hotFanPwm,
                rule.peltierOn,
                rule.swingOn
        );
    }

    public static ProfileRuleEntity toEntity(ProfileDtos.Rule dto, ProfileEntity profile) {
        ProfileRuleEntity rule = new ProfileRuleEntity();

        rule.id = parseRuleId(dto.id());
        rule.profile = profile;
        rule.dayOfWeek = clamp(dto.dayOfWeek(), 1, 7);
        rule.startTime = parseTime(dto.start(), LocalTime.of(8, 0));
        rule.endTime = parseTime(dto.end(), LocalTime.of(9, 0));
        rule.coldFanPwm = clamp(dto.coldFanPwm(), 0, 100);
        rule.hotFanPwm = clamp(dto.hotFanPwm(), 0, 100);
        rule.peltierOn = dto.peltierOn();
        rule.swingOn = dto.swingOn();

        return rule;
    }
    private static UUID parseRuleId(String id) {
        if (id == null || id.isBlank()) {
            return UUID.randomUUID();
        }

        return UUID.fromString(id);
    }

    private static int clamp(Integer value, int min, int max) {
        if (value == null) {
            return min;
        }

        return Math.max(min, Math.min(max, value));
    }

    private static LocalTime parseTime(String value, LocalTime fallback) {
        if (value == null) {
            return fallback;
        }

        try {
            return LocalTime.parse(value);
        } catch (Exception e) {
            return fallback;
        }
    }
}