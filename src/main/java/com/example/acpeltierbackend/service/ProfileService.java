package com.example.acpeltierbackend.service;

import com.example.acpeltierbackend.entity.ProfileEntity;
import com.example.acpeltierbackend.mapper.ProfileMapper;
import com.example.acpeltierbackend.repository.ProfileRepo;
import com.example.acpeltierbackend.web.dto.ProfileDtos;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Service
public class ProfileService {

    private final ProfileRepo repo;

    public ProfileService(ProfileRepo repo) {
        this.repo = repo;
    }

    @Transactional(readOnly = true)
    public List<ProfileDtos.ProfileSummary> listSummaries() {
        return repo.findAll()
                .stream()
                .sorted(Comparator.comparing(profile -> profile.name, String.CASE_INSENSITIVE_ORDER))
                .map(ProfileMapper::toSummary)
                .toList();
    }

    @Transactional
    public ProfileDtos.Profile create(String name) {
        if (repo.count() >= 3) {
            throw new IllegalStateException("Maximum " + 3 + " profiles allowed");
        }
        ProfileEntity profile = new ProfileEntity();
        profile.id = UUID.randomUUID();
        profile.name = normalizeName(name);
        profile.enabled = false;
        profile.rules = new ArrayList<>();
        return ProfileMapper.toProfile(repo.save(profile));
    }

    @Transactional(readOnly = true)
    public ProfileDtos.Profile get(String id) {
        ProfileEntity profile = findProfile(id);
        return ProfileMapper.toProfile(profile);
    }

    @Transactional
    public ProfileDtos.Profile save(String id, ProfileDtos.Profile incoming) {
        ProfileEntity profile = findProfile(id);
        if (incoming.name() != null && !incoming.name().isBlank()) {
            profile.name = incoming.name().trim();
        }
        profile.enabled = incoming.enabled();
        profile.rules.clear();
        if (incoming.rules() != null) {
            incoming.rules()
                    .stream()
                    .map(rule -> ProfileMapper.toEntity(rule, profile))
                    .forEach(profile.rules::add);
        }
        return ProfileMapper.toProfile(repo.save(profile));
    }

    @Transactional
    public void delete(String id) {
        UUID profileId = parseUuid(id);
        repo.findById(profileId).ifPresent(profile -> {
            if (profile.enabled) {
                profile.enabled = false;
                repo.save(profile);
            }
        });
        repo.deleteById(profileId);
    }

    @Transactional
    public void setEnabled(String id, boolean enabled) {
        UUID profileId = parseUuid(id);
        if (!enabled) {
            ProfileEntity profile = repo.findById(profileId)
                    .orElseThrow(() -> new NoSuchElementException("Profile not found"));
            profile.enabled = false;
            repo.save(profile);
            return;
        }

        List<ProfileEntity> profiles = repo.findAll();
        boolean found = false;
        for (ProfileEntity profile : profiles) {
            boolean shouldEnable = profile.id.equals(profileId);
            if (shouldEnable) {
                found = true;
            }
            profile.enabled = shouldEnable;
        }
        if (!found) {
            throw new NoSuchElementException("Profile not found");
        }
        repo.saveAll(profiles);
    }

    @Transactional(readOnly = true)
    public Optional<ProfileEntity> getEnabledProfileEntity() {
        List<ProfileEntity> enabledProfiles = repo.findByEnabledTrue();
        if (enabledProfiles.isEmpty()) {
            return Optional.empty();
        }
        return Optional.of(enabledProfiles.get(0));
    }

    private ProfileEntity findProfile(String id) {
        return repo.findById(parseUuid(id))
                .orElseThrow(() -> new NoSuchElementException("Profile not found"));
    }

    private static UUID parseUuid(String value) {
        try {
            return UUID.fromString(value);
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid UUID: " + value);
        }
    }

    private static String normalizeName(String name) {
        if (name == null || name.isBlank()) {
            return "New Profile";
        }
        return name.trim();
    }
}