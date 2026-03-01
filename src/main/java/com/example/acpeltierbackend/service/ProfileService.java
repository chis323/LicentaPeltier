package com.example.acpeltierbackend.service;

import com.example.acpeltierbackend.ProfileDtos;
import com.example.acpeltierbackend.db.ProfileEntity;
import com.example.acpeltierbackend.db.ProfileRepo;
import com.example.acpeltierbackend.db.ProfileRuleEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalTime;
import java.util.*;

@Service
public class ProfileService {

    private static final int MAX_PROFILES = 3;

    private final ProfileRepo repo;

    public ProfileService(ProfileRepo repo) {
        this.repo = repo;
    }

    @Transactional(readOnly = true)
    public List<ProfileDtos.ProfileSummary> listSummaries() {
        return repo.findAll().stream()
                .sorted(Comparator.comparing(p -> safeLower(p.name)))
                .map(p -> new ProfileDtos.ProfileSummary(p.id.toString(), p.name, p.enabled))
                .toList();
    }

    @Transactional
    public ProfileDtos.Profile create(String name) {
        // Enforce MAX 3 profiles
        long count = repo.count();
        if (count >= MAX_PROFILES) {
            throw new IllegalStateException("Maximum " + MAX_PROFILES + " profiles allowed");
        }

        ProfileEntity p = new ProfileEntity();
        p.id = UUID.randomUUID();
        p.name = normalizeName(name);
        p.enabled = false;
        p.rules = new ArrayList<>();

        return toDto(repo.save(p));
    }

    @Transactional(readOnly = true)
    public ProfileDtos.Profile get(String id) {
        ProfileEntity p = repo.findById(parseUuid(id))
                .orElseThrow(() -> new NoSuchElementException("Profile not found"));

        // ensure rules loaded (if LAZY)
        p.rules.size();
        return toDto(p);
    }

    @Transactional
    public ProfileDtos.Profile save(String id, ProfileDtos.Profile incoming) {
        ProfileEntity p = repo.findById(parseUuid(id))
                .orElseThrow(() -> new NoSuchElementException("Profile not found"));

        // Update name (only if non-blank)
        if (incoming.name() != null && !incoming.name().isBlank()) {
            p.name = incoming.name().trim();
        }

        // enabled flag is allowed here too (but you typically enable via /enable endpoint)
        p.enabled = incoming.enabled();

        // Replace all rules (orphanRemoval=true)
        p.rules.clear();

        if (incoming.rules() != null) {
            for (ProfileDtos.Rule r : incoming.rules()) {
                ProfileRuleEntity e = new ProfileRuleEntity();
                e.id = (r.id() != null && !r.id().isBlank()) ? parseUuid(r.id()) : UUID.randomUUID();
                e.profile = p;
                e.dayOfWeek = clamp(r.dayOfWeek(), 1, 7);
                e.startTime = parseTime(r.start(), LocalTime.of(8, 0));
                e.endTime = parseTime(r.end(), LocalTime.of(9, 0));
                e.coldFanPwm = clamp(r.coldFanPwm(), 0, 100);
                e.hotFanPwm = clamp(r.hotFanPwm(), 0, 100);
                e.peltierOn = r.peltierOn();
                e.swingOn = r.swingOn();
                p.rules.add(e);
            }
        }

        return toDto(repo.save(p));
    }

    @Transactional
    public void delete(String id) {
        UUID pid = parseUuid(id);

        // Disable first (cleaner)
        repo.findById(pid).ifPresent(p -> {
            if (p.enabled) {
                p.enabled = false;
                repo.save(p);
            }
        });

        // orphanRemoval=true should remove rules automatically
        repo.deleteById(pid);
    }

    /**
     * Enforces ONE enabled profile: enabling one disables all others.
     * Also avoids excessive saves by only saving when state changes.
     */
    @Transactional
    public void setEnabled(String id, boolean enabled) {
        UUID pid = parseUuid(id);

        if (!enabled) {
            ProfileEntity p = repo.findById(pid).orElseThrow(() -> new NoSuchElementException("Profile not found"));
            if (p.enabled) {
                p.enabled = false;
                repo.save(p);
            }
            return;
        }

        // enable requested one; disable others
        List<ProfileEntity> all = repo.findAll();
        boolean found = false;

        for (ProfileEntity p : all) {
            boolean shouldEnable = p.id.equals(pid);
            if (shouldEnable) found = true;

            if (p.enabled != shouldEnable) {
                p.enabled = shouldEnable;
            }
        }

        if (!found) {
            throw new NoSuchElementException("Profile not found");
        }

        repo.saveAll(all);
    }

    @Transactional(readOnly = true)
    public Optional<ProfileEntity> getEnabledProfileEntity() {
        List<ProfileEntity> enabled = repo.findByEnabledTrue();
        if (enabled.isEmpty()) return Optional.empty();
        // if multiple enabled (shouldn't happen), pick the first
        return Optional.of(enabled.get(0));
    }

    // ===== helpers =====

    private static UUID parseUuid(String s) {
        try {
            return UUID.fromString(s);
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid UUID: " + s);
        }
    }

    private static int clamp(Integer v, int lo, int hi) {
        if (v == null) return lo;
        return Math.max(lo, Math.min(hi, v));
    }

    private static LocalTime parseTime(String s, LocalTime fallback) {
        if (s == null) return fallback;
        try {
            return LocalTime.parse(s);
        } catch (Exception ignore) {
            return fallback;
        }
    }

    private static String normalizeName(String name) {
        if (name == null || name.isBlank()) return "New Profile";
        return name.trim();
    }

    private static String safeLower(String s) {
        if (s == null) return "";
        return s.toLowerCase(Locale.ROOT);
    }

    private static ProfileDtos.Profile toDto(ProfileEntity p) {
        List<ProfileDtos.Rule> rules = p.rules.stream()
                .sorted(Comparator
                        .comparingInt((ProfileRuleEntity r) -> r.dayOfWeek)
                        .thenComparing(r -> r.startTime))
                .map(r -> new ProfileDtos.Rule(
                        r.id.toString(),
                        r.dayOfWeek,
                        r.startTime.toString(),
                        r.endTime.toString(),
                        r.coldFanPwm,
                        r.hotFanPwm,
                        r.peltierOn,
                        r.swingOn
                ))
                .toList();

        return new ProfileDtos.Profile(p.id.toString(), p.name, p.enabled, rules);
    }
}