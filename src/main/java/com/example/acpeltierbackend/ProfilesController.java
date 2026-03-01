package com.example.acpeltierbackend;

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
    public ProfileDtos.Profile create(@RequestBody ProfileDtos.CreateProfileReq req) {
        return service.create(req.name());
    }


    @PutMapping("/{id}")
    public ProfileDtos.Profile save(@PathVariable String id, @RequestBody ProfileDtos.Profile incoming) {

        return service.save(id, incoming);
    }


    @PostMapping("/{id}/enable")
    public Map<String, Object> enable(@PathVariable String id, @RequestBody ProfileDtos.EnableReq req) {
        service.setEnabled(id, req.enabled());
        return Map.of("ok", true);
    }


    @DeleteMapping("/{id}")
    public Map<String, Object> delete(@PathVariable String id) {
        service.delete(id);
        return Map.of("ok", true);
    }
}