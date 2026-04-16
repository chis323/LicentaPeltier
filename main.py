#!/usr/bin/env python3
import asyncio
import json
import time
from pathlib import Path

import websockets
from gpiozero import DigitalOutputDevice, PWMOutputDevice

import board
import adafruit_dht

PC_HOST = "licentapeltier.onrender.com"
DEVICE_KEY = "CHANGE_ME_DEVICE_KEY"
BACKEND_WS = f"wss://{PC_HOST}/ws/device?key={DEVICE_KEY}"

TELEMETRY_INTERVAL_SEC = 2.0

PELTIERSW_PIN = 20
FAN_ALWAYS_ON_PIN = 18
FAN_PWM_PIN = 26

DHT_PIN = board.D4
DHT_USE_PULSEIO = False

PWMCHIP_STR = "/sys/class/pwm/pwmchip0"
CHIP = Path(PWMCHIP_STR)
SERVO_PWM = CHIP / "pwm3"

SERVO_PERIOD = 20_000_000
SERVO_MIN = 10_000
SERVO_MID = 800_000
SERVO_MAX = 1_500_000


async def delay(seconds: float):
    await asyncio.sleep(seconds)


async def delay_ms(milliseconds: int):
    await asyncio.sleep(milliseconds / 1000.0)


def current_epoch_ms() -> int:
    return int(time.time() * 1000)


def clamp_int(x, lo=0, hi=100):
    try:
        x = int(x)
    except Exception:
        return None
    return max(lo, min(hi, x))


def write_path(path: Path, value: int):
    path.write_text(str(value))


async def ensure_servo_exported():
    if not SERVO_PWM.exists():
        write_path(CHIP / "export", 3)
        await delay_ms(100)

    if not SERVO_PWM.exists():
        raise RuntimeError(f"{SERVO_PWM} missing after export")


def servo_enable():
    write_path(SERVO_PWM / "enable", 0)
    write_path(SERVO_PWM / "period", SERVO_PERIOD)
    write_path(SERVO_PWM / "duty_cycle", SERVO_MID)
    write_path(SERVO_PWM / "enable", 1)


def servo_disable():
    try:
        write_path(SERVO_PWM / "enable", 0)
    except Exception:
        pass


def servo_set_ns(duty_ns: int):
    duty_ns = max(0, min(SERVO_PERIOD, int(duty_ns)))
    write_path(SERVO_PWM / "duty_cycle", duty_ns)


class Hardware:
    def __init__(self):
        self.peltier = DigitalOutputDevice(
            PELTIERSW_PIN,
            active_high=True,
            initial_value=False,
        )

        self.fan18 = DigitalOutputDevice(
            FAN_ALWAYS_ON_PIN,
            active_high=True,
            initial_value=False,
        )

        self.fan26 = PWMOutputDevice(
            FAN_PWM_PIN,
            active_high=True,
            initial_value=0.0,
        )

        self.servo_ok = False
        self.swing_task: asyncio.Task | None = None

        self.dht = None
        self.dht_ready = False
        self.dht_init_task: asyncio.Task | None = None

        self.state = {
            "swingOn": False,
            "coldFanPwm": 0,
            "hotFanPwm": 0,
            "peltierOn": False,
        }

    async def async_init(self):
        await self.init_servo()
        await self.init_dht()

    async def init_servo(self):
        try:
            await ensure_servo_exported()
            servo_enable()
            self.servo_ok = True
        except PermissionError:
            print("[HW] Servo permission denied. Run with sudo.")
        except Exception as e:
            print("[HW] Servo init failed:", repr(e))

    async def init_dht(self):
        try:
            print("[HW] Initializing DHT22 on GPIO4...")
            self.dht = adafruit_dht.DHT22(DHT_PIN, use_pulseio=DHT_USE_PULSEIO)
            self.dht_ready = False

            async def mark_ready():
                await delay(2)
                self.dht_ready = True

            self.dht_init_task = asyncio.create_task(mark_ready())
        except Exception as e:
            print("[HW] DHT init failed:", repr(e))
            self.dht = None
            self.dht_ready = False

    async def reinit_dht(self):
        try:
            if self.dht is not None:
                self.dht.exit()
        except Exception:
            pass

        self.dht = None
        self.dht_ready = False

        await delay(2)

        try:
            self.dht = adafruit_dht.DHT22(DHT_PIN, use_pulseio=DHT_USE_PULSEIO)
            self.dht_ready = False

            async def mark_ready():
                await delay(2)
                self.dht_ready = True

            self.dht_init_task = asyncio.create_task(mark_ready())
        except Exception as e:
            print("[HW] DHT reinit failed:", repr(e))
            self.dht = None
            self.dht_ready = False

    def shutdown(self):
        try:
            if self.swing_task and not self.swing_task.done():
                self.swing_task.cancel()
        except Exception:
            pass

        try:
            if self.dht_init_task and not self.dht_init_task.done():
                self.dht_init_task.cancel()
        except Exception:
            pass

        try:
            self.peltier.off()
            self.peltier.close()
        except Exception:
            pass

        try:
            self.fan18.off()
            self.fan18.close()
        except Exception:
            pass

        try:
            self.fan26.value = 0.0
            self.fan26.close()
        except Exception:
            pass

        try:
            servo_disable()
        except Exception:
            pass

        try:
            if self.dht is not None:
                self.dht.exit()
        except Exception:
            pass

    async def read_dht22(self):
        if self.dht is None or not self.dht_ready:
            return None, None

        try:
            temperature = self.dht.temperature
            humidity = self.dht.humidity
            return temperature, humidity
        except RuntimeError:
            return None, None
        except Exception as e:
            print("[HW] DHT error:", repr(e), "-> reinit")
            await self.reinit_dht()
            return None, None

    def set_cold_fan_pwm(self, pwm_0_100: int):
        self.state["coldFanPwm"] = pwm_0_100
        self.fan26.value = pwm_0_100 / 100.0
        print(f"[HW] cold fan (GPIO26) -> {pwm_0_100}%")

    def set_hot_fan_pwm(self, pwm_0_100: int):
        self.state["hotFanPwm"] = pwm_0_100
        if pwm_0_100 > 0:
            self.fan18.on()
            print("[HW] hot fan (GPIO18) -> ON")
        else:
            self.fan18.off()
            print("[HW] hot fan (GPIO18) -> OFF")

    def set_peltier(self, on: bool):
        self.state["peltierOn"] = on
        if on:
            self.peltier.on()
            print("[HW] peltier (GPIO20) -> ON")
        else:
            self.peltier.off()
            print("[HW] peltier (GPIO20) -> OFF")

    def set_swing(self, on: bool):
        self.state["swingOn"] = on
        print(f"[HW] swing -> {on}")

    async def swing_loop(self):
        if not self.servo_ok:
            return

        try:
            while self.state.get("swingOn"):
                await self.servo_ramp_async(SERVO_MIN, SERVO_MAX, seconds=2.5, hz=80)
                await self.servo_ramp_async(SERVO_MAX, SERVO_MIN, seconds=2.5, hz=80)

            servo_set_ns(SERVO_MID)
        except asyncio.CancelledError:
            try:
                servo_set_ns(SERVO_MID)
            except Exception:
                pass
            raise

    async def servo_ramp_async(self, start, end, seconds=2.5, hz=80):
        steps = max(1, int(seconds * hz))
        dt = seconds / steps

        for i in range(steps + 1):
            if not self.state.get("swingOn"):
                return
            pulse = int(start + (end - start) * (i / steps))
            servo_set_ns(pulse)
            await delay(dt)

    def ensure_swing_task(self):
        if self.state.get("swingOn"):
            if self.swing_task is None or self.swing_task.done():
                self.swing_task = asyncio.create_task(self.swing_loop())
        else:
            if self.swing_task and not self.swing_task.done():
                self.swing_task.cancel()


def read_other_temps():
    return None, None


async def telemetry_loop(ws, hw: Hardware):
    while True:
        ambient_temp, humidity = await hw.read_dht22()
        hot_temp, cold_temp = read_other_temps()

        msg = {
            "type": "telemetry",
            "ts": current_epoch_ms(),
            "ambientTempC": ambient_temp,
            "humidityPct": humidity,
            "hotSideTempC": hot_temp,
            "coldSideTempC": cold_temp,
            "coldFanPwm": hw.state.get("coldFanPwm"),
            "hotFanPwm": hw.state.get("hotFanPwm"),
            "peltierOn": hw.state.get("peltierOn"),
            "swingOn": hw.state.get("swingOn"),
            "fault": None,
        }

        await ws.send(json.dumps(msg))
        print("[NET] sent telemetry")
        await delay(TELEMETRY_INTERVAL_SEC)


def apply_command(payload, hw: Hardware):
    if "swingOn" in payload and payload["swingOn"] is not None:
        hw.set_swing(bool(payload["swingOn"]))
        hw.ensure_swing_task()

    if "coldFanPwm" in payload and payload["coldFanPwm"] is not None:
        value = clamp_int(payload["coldFanPwm"])
        if value is not None:
            hw.set_cold_fan_pwm(value)

    if "hotFanPwm" in payload and payload["hotFanPwm"] is not None:
        value = clamp_int(payload["hotFanPwm"])
        if value is not None:
            hw.set_hot_fan_pwm(value)

    if "peltierOn" in payload and payload["peltierOn"] is not None:
        hw.set_peltier(bool(payload["peltierOn"]))


async def receiver_loop(ws, hw: Hardware):
    async for raw in ws:
        print("[NET] received:", raw)
        try:
            data = json.loads(raw)
        except Exception:
            continue

        if data.get("type") == "command":
            payload = data.get("payload") or {}
            apply_command(payload, hw)


async def main():
    hw = Hardware()
    await hw.async_init()

    backoff = 1

    try:
        while True:
            try:
                print(f"[NET] connecting -> {BACKEND_WS}")
                async with websockets.connect(
                    BACKEND_WS,
                    ping_interval=20,
                    ping_timeout=20,
                    open_timeout=30,
                ) as ws:
                    print("[NET] connected ✅")
                    backoff = 1
                    await asyncio.gather(
                        telemetry_loop(ws, hw),
                        receiver_loop(ws, hw),
                    )
            except Exception as e:
                print("[NET] disconnected:", type(e).__name__, repr(e))
                print(f"[NET] retry in {backoff}s...")
                await delay(backoff)
                backoff = min(backoff * 2, 30)
    finally:
        hw.shutdown()


if __name__ == "__main__":
    asyncio.run(main())
