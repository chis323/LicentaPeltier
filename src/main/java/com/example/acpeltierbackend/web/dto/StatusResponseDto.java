package com.example.acpeltierbackend.web.dto;

public record StatusResponseDto(
        boolean deviceOnline,
        Long ts,
        Double ambientTempC,
        Double humidityPct,
        Integer coldFanPwm,
        Integer hotFanPwm,
        Boolean peltierOn,
        Boolean swingOn
) {
}