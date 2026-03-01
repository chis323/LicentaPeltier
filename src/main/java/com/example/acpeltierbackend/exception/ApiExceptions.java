package com.example.acpeltierbackend.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

public class ApiExceptions {

    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public static class ProfileLimitReachedException extends RuntimeException {
        public ProfileLimitReachedException(String message) {
            super(message);
        }
    }
}