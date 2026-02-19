package com.example.acpeltierbackend;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public class Dtos {

    public static class CommandRequest {
        public Boolean swingOn;

        @Min(0) @Max(100)
        public Integer coldFanPwm;

        @Min(0) @Max(100)
        public Integer hotFanPwm;

        @Min(0) @Max(100)
        public Integer peltierPwm;
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
        public Integer peltierPwm;

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
        public Integer peltierPwm;

        public Boolean swingOn;
        public String fault;
    }
}
