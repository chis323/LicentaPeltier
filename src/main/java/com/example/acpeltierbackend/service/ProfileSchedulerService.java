package com.example.acpeltierbackend.service;

import com.example.acpeltierbackend.web.dto.CommandRequestDto;
import com.example.acpeltierbackend.entity.ProfileEntity;
import com.example.acpeltierbackend.entity.ProfileRuleEntity;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.*;
import java.util.Comparator;
import java.util.Optional;

@Service
public class ProfileSchedulerService {

    private final ProfileService profileService;
    private final CommandSenderService sender;
    private CommandRequestDto lastApplied = null;
    private final ZoneId zone = ZoneId.of("Europe/Bucharest");

    public ProfileSchedulerService(ProfileService profileService, CommandSenderService sender) {
        this.profileService = profileService;
        this.sender = sender;
    }

    @Scheduled(fixedDelay = 5_000)
    public void tick() {
        try {
            Optional<ProfileEntity> enabledOpt = profileService.getEnabledProfileEntity();
            if (enabledOpt.isEmpty()) {
                applyIdleIfNeeded("no enabled profile");
                return;
            }

            ProfileEntity p = enabledOpt.get();
            ZonedDateTime now = ZonedDateTime.now(zone);
            ProfileRuleEntity match = p.rules.stream()
                    .filter(r -> matchesRule(now, r))
                    .max(Comparator.comparing((ProfileRuleEntity r) -> r.startTime))
                    .orElse(null);

            if (match == null) {
                applyIdleIfNeeded("no matching block");
                return;
            }

            CommandRequestDto cmd = new CommandRequestDto(
                    match.swingOn,
                    match.coldFanPwm,
                    match.hotFanPwm,
                    match.peltierOn
            );

            if (cmd.equals(lastApplied)) {
                return;
            }

            boolean ok = sender.sendCommand(cmd);
            if (ok) {
                lastApplied = cmd;
                System.out.printf("[SCHED] applied profile '%s' block: DOW=%d %s-%s -> cold=%d hot=%d peltier=%s swing=%s (zone=%s now=%s)%n",
                        p.name,
                        match.dayOfWeek,
                        match.startTime,
                        match.endTime,
                        cmd.coldFanPwm(),
                        cmd.hotFanPwm(),
                        cmd.peltierOn(),
                        cmd.swingOn(),
                        zone,
                        now);
            } else {
                System.out.println("[SCHED] device offline, cannot send command");
            }

        } catch (Exception e) {
            System.out.println("[SCHED] ERROR: " + e.getMessage());
        }
    }

    private void applyIdleIfNeeded(String reason) {
        CommandRequestDto idle = new CommandRequestDto(
                false,
                0,
                0,
                false
        );

        if (idle.equals(lastApplied)) {
            return;
        }

        boolean ok = sender.sendCommand(idle);
        if (ok) {
            lastApplied = idle;
            System.out.println("[SCHED] applied IDLE (" + reason + ")");
        } else {
            System.out.println("[SCHED] device offline, cannot send IDLE (" + reason + ")");
        }
    }

    private static boolean matchesRule(ZonedDateTime now, ProfileRuleEntity r) {
        int dow = now.getDayOfWeek().getValue();
        LocalTime t = now.toLocalTime().withSecond(0).withNano(0);

        if (r.startTime.isBefore(r.endTime)) {
            return r.dayOfWeek == dow && !t.isBefore(r.startTime) && t.isBefore(r.endTime);
        }

        if (r.startTime.isAfter(r.endTime)) {
            if (!t.isBefore(r.startTime)) {
                return r.dayOfWeek == dow;
            }

            if (t.isBefore(r.endTime)) {
                int previousDow = dow == 1 ? 7 : dow - 1;
                return r.dayOfWeek == previousDow;
            }
        }

        return r.startTime.equals(r.endTime) && r.dayOfWeek == dow;
    }
}