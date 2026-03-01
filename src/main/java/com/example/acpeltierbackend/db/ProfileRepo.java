package com.example.acpeltierbackend.db;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ProfileRepo extends JpaRepository<ProfileEntity, UUID> {
    List<ProfileEntity> findByEnabledTrue();
}
