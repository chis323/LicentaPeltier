package com.example.acpeltierbackend.service;

import com.example.acpeltierbackend.web.dto.Dtos;
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


    private Dtos.CommandRequest lastApplied = null;


    private final ZoneId zone = ZoneId.systemDefault();

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
            int dow = now.getDayOfWeek().getValue();
            LocalTime t = now.toLocalTime().withSecond(0).withNano(0);

            ProfileRuleEntity match = p.rules.stream()
                    .filter(r -> r.dayOfWeek == dow)
                    .filter(r -> inRange(t, r.startTime, r.endTime)).max(Comparator.comparing((ProfileRuleEntity r) -> r.startTime))
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
                        cmd.swingOn,
                        zone,
                        now
                );
            } else {
                System.out.println("[SCHED] device offline, cannot send command");
            }

        } catch (Exception e) {

            System.out.println("[SCHED] ERROR: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private void applyIdleIfNeeded(String reason) {

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

        if (start.equals(end)) return true;

        if (start.isBefore(end)) {
            return !now.isBefore(start) && now.isBefore(end);
        }

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