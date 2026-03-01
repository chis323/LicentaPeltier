package com.example.acpeltierbackend.service;

import com.example.acpeltierbackend.Dtos;
import com.example.acpeltierbackend.db.ProfileEntity;
import com.example.acpeltierbackend.db.ProfileRuleEntity;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.*;
import java.util.Comparator;
import java.util.Optional;

@Component
public class ProfileScheduler {

    private final ProfileService profileService;
    private final CommandSender sender;

    // Cache last sent command to avoid spamming
    private Dtos.CommandRequest lastApplied = null;

    // Use local timezone for schedule matching (recommended)
    private final ZoneId zone = ZoneId.systemDefault();
    // If you want to force a zone, use e.g.:
    // private final ZoneId zone = ZoneId.of("Europe/Bucharest");

    public ProfileScheduler(ProfileService profileService, CommandSender sender) {
        this.profileService = profileService;
        this.sender = sender;
    }

    // For testing use 5s; once OK, switch back to 30_000
    @Scheduled(fixedDelay = 5_000)
    public void tick() {
        try {
            Optional<ProfileEntity> enabledOpt = profileService.getEnabledProfileEntity();
            if (enabledOpt.isEmpty()) {
                // No enabled profile: optionally send idle once
                applyIdleIfNeeded("no enabled profile");
                return;
            }

            ProfileEntity p = enabledOpt.get();

            ZonedDateTime now = ZonedDateTime.now(zone);
            int dow = now.getDayOfWeek().getValue(); // 1=Mon..7=Sun
            LocalTime t = now.toLocalTime().withSecond(0).withNano(0);

            ProfileRuleEntity match = p.rules.stream()
                    .filter(r -> r.dayOfWeek == dow)
                    .filter(r -> inRange(t, r.startTime, r.endTime))
                    // pick the most specific match if overlaps exist:
                    // latest start time that still contains "now"
                    .sorted(Comparator.comparing((ProfileRuleEntity r) -> r.startTime).reversed())
                    .findFirst()
                    .orElse(null);

            if (match == null) {
                applyIdleIfNeeded("no matching block");
                return;
            }

            Dtos.CommandRequest cmd = new Dtos.CommandRequest();
            cmd.coldFanPwm = match.coldFanPwm;
            cmd.hotFanPwm = match.hotFanPwm;
            cmd.peltierPwm = match.peltierOn ? 100 : 0;
            cmd.swingOn = match.swingOn;

            if (same(cmd, lastApplied)) {
                // System.out.println("[SCHED] same as last, skip");
                return;
            }

            boolean ok = sender.sendCommand(cmd);
            if (ok) {
                lastApplied = cmd;
                System.out.printf(
                        "[SCHED] applied profile '%s' block: DOW=%d %s-%s -> cold=%d hot=%d peltier=%d swing=%s (zone=%s now=%s)%n",
                        p.name,
                        match.dayOfWeek,
                        match.startTime,
                        match.endTime,
                        cmd.coldFanPwm,
                        cmd.hotFanPwm,
                        cmd.peltierPwm,
                        String.valueOf(cmd.swingOn),
                        zone,
                        now
                );
            } else {
                System.out.println("[SCHED] device offline, cannot send command");
            }

        } catch (Exception e) {
            // Never let the scheduler die silently
            System.out.println("[SCHED] ERROR: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private void applyIdleIfNeeded(String reason) {
        // OPTIONAL BEHAVIOR:
        // If you want the device to "stop" when outside any block,
        // send a neutral command once.
        //
        // If you *don't* want this, delete this method and just return.

        Dtos.CommandRequest idle = new Dtos.CommandRequest();
        idle.coldFanPwm = 0;
        idle.hotFanPwm = 0;
        idle.peltierPwm = 0;
        idle.swingOn = false;

        if (same(idle, lastApplied)) return;

        boolean ok = sender.sendCommand(idle);
        if (ok) {
            lastApplied = idle;
            System.out.println("[SCHED] applied IDLE (" + reason + ")");
        } else {
            System.out.println("[SCHED] device offline, cannot send IDLE (" + reason + ")");
        }
    }

    private static boolean inRange(LocalTime now, LocalTime start, LocalTime end) {
        // supports ranges that cross midnight, e.g. 22:00-02:00
        if (start.equals(end)) return true;

        if (start.isBefore(end)) {
            return !now.isBefore(start) && now.isBefore(end);
        }
        // wraps midnight
        return !now.isBefore(start) || now.isBefore(end);
    }

    private static boolean same(Dtos.CommandRequest a, Dtos.CommandRequest b) {
        if (a == b) return true;
        if (a == null || b == null) return false;
        return eq(a.coldFanPwm, b.coldFanPwm)
                && eq(a.hotFanPwm, b.hotFanPwm)
                && eq(a.peltierPwm, b.peltierPwm)
                && eq(a.swingOn, b.swingOn);
    }

    private static boolean eq(Object x, Object y) {
        if (x == y) return true;
        if (x == null || y == null) return false;
        return x.equals(y);
    }
}