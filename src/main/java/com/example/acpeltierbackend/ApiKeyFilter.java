package com.example.acpeltierbackend;

import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class ApiKeyFilter extends OncePerRequestFilter {
    private final AppConfig cfg;

    public ApiKeyFilter(AppConfig cfg) {
        this.cfg = cfg;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, @NonNull HttpServletResponse res, @NonNull FilterChain chain)
            throws java.io.IOException, jakarta.servlet.ServletException {

        if (!req.getRequestURI().startsWith("/api/")) {
            chain.doFilter(req, res);
            return;
        }

        String key = req.getParameter("key");

        System.out.println(">>> EXPECTED API KEY = [" + cfg.apiKey + "]");
        System.out.println(">>> PROVIDED API KEY = [" + key + "]");
        System.out.println(">>> FULL URL = " + req.getRequestURL() + "?" + req.getQueryString());

        if (key == null || !key.equals(cfg.apiKey)) {
            res.setStatus(401);
            res.getWriter().write("Unauthorized");
            return;
        }

        chain.doFilter(req, res);
    }
}
