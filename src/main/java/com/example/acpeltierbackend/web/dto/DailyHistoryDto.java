package com.example.acpeltierbackend.web.dto;

import java.time.LocalDate;

public record DailyHistoryDto(
        LocalDate day,
        Double minAmbientTempC,
        Double maxAmbientTempC
){
}
