package com.example.acpeltierbackend.web.controller;

import com.example.acpeltierbackend.web.dto.ProfileDtos;
import com.example.acpeltierbackend.service.ProfileService;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/profiles")
public class ProfilesController {

    private final ProfileService service;
    public ProfilesController(ProfileService service) {
        this.service = service;
    }

    @GetMapping
    public Map<String, Object> list() {
        List<ProfileDtos.ProfileSummary> summaries = service.listSummaries();
        Map<String, Object> out = new HashMap<>();
        out.put("profiles", summaries);
        return out;
    }

    @GetMapping("/{id}")
    public ProfileDtos.Profile get(@PathVariable String id) {
        return service.get(id);
    }

    @PostMapping
    public ProfileDtos.Profile create(@RequestBody ProfileDtos.CreateNewProfileRequest req) {
        return service.create(req.name());
    }

    @PutMapping("/{id}")
    public ProfileDtos.Profile save(@PathVariable String id, @RequestBody ProfileDtos.Profile incoming) {
        return service.save(id, incoming);
    }

    @PostMapping("/{id}/enable")
    public void enable(@PathVariable String id, @RequestBody ProfileDtos.EnableProfileRequest req) {
        service.setEnabled(id, req.enabled());
    }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable String id) {
        service.delete(id);
    }
}