package com.example.acpeltierbackend.web.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public record CommandRequestDto(
        Boolean swingOn,
        @Min(0)
        @Max(100)
        Integer coldFanPwm,
        @Min(0)
        @Max(100)
        Integer hotFanPwm,
        Boolean peltierOn
) {
}