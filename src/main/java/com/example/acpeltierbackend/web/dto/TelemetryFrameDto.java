package com.example.acpeltierbackend.web.dto;

public class TelemetryFrameDto {
    public String type;
    public Long ts;
    public Double ambientTempC;
    public Double humidityPct;
    public Integer coldFanPwm;
    public Integer hotFanPwm;
    public Boolean peltierOn;
    public Boolean swingOn;
}
