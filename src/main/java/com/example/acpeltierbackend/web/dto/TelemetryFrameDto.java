package com.example.acpeltierbackend.web.dto;

public record TelemetryFrameDto(
        String type,
        Long ts,
        Double ambientTempC,
        Double humidityPct,
        Integer coldFanPwm,
        Integer hotFanPwm,
        Boolean peltierOn,
        Boolean swingOn
){
}