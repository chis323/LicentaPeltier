package com.example.acpeltierbackend;

import java.util.List;

public class ProfileDtos {

    // Small list view
    public record ProfileSummary(String id, String name, boolean enabled) {}

    // Full profile
    public record Profile(String id, String name, boolean enabled, List<Rule> rules) {}

    // Single time block
    public record Rule(
            String id,
            int dayOfWeek,     // 1=Mon..7=Sun
            String start,      // "HH:mm"
            String end,        // "HH:mm"
            int coldFanPwm,    // 0..100
            int hotFanPwm,     // 0..100
            boolean peltierOn,
            boolean swingOn
    ) {}

    // POST /api/profiles request
    public record CreateProfileReq(String name) {}

    // POST /api/profiles/{id}/enable request
    public record EnableReq(boolean enabled) {}
}