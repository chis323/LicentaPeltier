package com.example.acpeltierbackend.web.dto;

import java.util.List;

public class ProfileDtos {

    public record ProfileSummary(String id, String name, boolean enabled) {
    }

    public record Profile(String id, String name, boolean enabled, List<Rule> rules) {
    }

    public record Rule(String id, int dayOfWeek, String start, String end, int coldFanPwm, int hotFanPwm,
                       boolean peltierOn, boolean swingOn) {
    }


    public record CreateProfileReq(String name) {
    }


    public record EnableReq(boolean enabled) {
    }
}