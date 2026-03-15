package com.example.acpeltierbackend.web.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public class Dtos {

    public static class CommandRequest {
        public Boolean swingOn;

        @Min(0) @Max(100)
        public Integer coldFanPwm;

        @Min(0) @Max(100)
        public Integer hotFanPwm;

        public Boolean peltierOn;
    }

    public static class StatusResponse {
        public boolean deviceOnline;

        public Long ts;

        public Double ambientTempC;
        public Double humidityPct;

        public Double hotSideTempC;
        public Double coldSideTempC;

        public Integer coldFanPwm;
        public Integer hotFanPwm;
        public Boolean peltierOn;

        public Boolean swingOn;
        public String fault;
    }

    public static class TelemetryFrame {
        public String type;
        public Long ts;

        public Double ambientTempC;
        public Double humidityPct;

        public Double hotSideTempC;
        public Double coldSideTempC;

        public Integer coldFanPwm;
        public Integer hotFanPwm;
        public Boolean peltierOn;

        public Boolean swingOn;
        public String fault;
    }
}