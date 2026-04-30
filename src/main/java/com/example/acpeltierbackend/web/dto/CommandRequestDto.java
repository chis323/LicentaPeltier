package com.example.acpeltierbackend.web.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public class CommandRequestDto {
    public Boolean swingOn;

    @Min(0) @Max(100)
    public Integer coldFanPwm;

    @Min(0) @Max(100)
    public Integer hotFanPwm;

    public Boolean peltierOn;
}