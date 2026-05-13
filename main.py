#!/usr/bin/env python3
import asyncio
import json
import time
from pathlib import Path

import board
import adafruit_dht
import websockets
from gpiozero import DigitalOutputDevice, PWMOutputDevice


PC_HOST = "licentapeltier.onrender.com"
DEVICE_KEY = "CHANGE_ME_DEVICE_KEY"
BACKEND_WS = f"wss://{PC_HOST}/ws/device?key={DEVICE_KEY}"

TELEMETRY_INTERVAL_SEC = 2.0

PELTIERSW_PIN = 20
FAN_ALWAYS_ON_PIN = 18
FAN_PWM_PIN = 26

DHT_PIN = board.D4
DHT_USE_PULSEIO = False

CHIP = Path("/sys/class/pwm/pwmchip0")
SERVO_PWM = CHIP / "pwm3"

SERVO_CHANNEL = 3
SERVO_PERIOD = 20_000_000
SERVO_MIN = 10_000
SERVO_MID = 800_000
SERVO_MAX = 1_500_000


async def sleep_ms(ms: int):
    await asyncio.sleep(ms / 1000)


def now_ms() -> int:
    return int(time.time() * 1000)


def clamp_int(value, lo=0, hi=100):
    try:
        value = int(value)
        return max(lo, min(hi, value))
    except Exception:
        return None


def write(path: Path, value):
    path.write_text(str(value))


async def ensure_servo_exported():
    if not SERVO_PWM.exists():
        write(CHIP / "export", SERVO_CHANNEL)
        await sleep_ms(100)

    if not SERVO_PWM.exists():
        raise RuntimeError(f"{SERVO_PWM} missing after export")


def servo_enable():
    write(SERVO_PWM / "enable", 0)
    write(SERVO_PWM / "period", SERVO_PERIOD)
    write(SERVO_PWM / "duty_cycle", SERVO_MID)
    write(SERVO_PWM / "enable", 1)


def servo_disable():
    try:
        write(SERVO_PWM / "enable", 0)
    except Exception:
        pass


def servo_set_ns(duty_ns: int):
    duty_ns = max(0, min(SERVO_PERIOD, int(duty_ns)))
    write(SERVO_PWM / "duty_cycle", duty_ns)


class Hardware:
    def __init__(self):
        self.peltier = DigitalOutputDevice(PELTIERSW_PIN, active_high=True, initial_value=False)
        self.hot_fan = DigitalOutputDevice(FAN_ALWAYS_ON_PIN, active_high=True, initial_value=False)
        self.cold_fan = PWMOutputDevice(FAN_PWM_PIN, active_high=True, initial_value=0.0)

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
            self.dht_init_task = asyncio.create_task(self.mark_dht_ready())
        except Exception as e:
            print("[HW] DHT init failed:", repr(e))
            self.dht = None
            self.dht_ready = False

    async def mark_dht_ready(self):
        await asyncio.sleep(2)
        self.dht_ready = True

    async def reinit_dht(self):
        try:
            if self.dht:
                self.dht.exit()
        except Exception:
            pass

        self.dht = None
        self.dht_ready = False

        await asyncio.sleep(2)
        await self.init_dht()

    async def read_dht22(self):
        if not self.dht or not self.dht_ready:
            return None, None

        try:
            return self.dht.temperature, self.dht.humidity
        except RuntimeError:
            return None, None
        except Exception as e:
            print("[HW] DHT error:", repr(e), "-> reinit")
            await self.reinit_dht()
            return None, None

    def set_cold_fan_pwm(self, value: int):
        self.state["coldFanPwm"] = value
        self.cold_fan.value = value / 100
        print(f"[HW] cold fan (GPIO26) -> {value}%")

    def set_hot_fan_pwm(self, value: int):
        self.state["hotFanPwm"] = value

        if value > 0:
            self.hot_fan.on()
            print("[HW] hot fan (GPIO18) -> ON")
        else:
            self.hot_fan.off()
            print("[HW] hot fan (GPIO18) -> OFF")

    def set_peltier(self, enabled: bool):
        self.state["peltierOn"] = enabled

        if enabled:
            self.peltier.on()
            print("[HW] peltier (GPIO20) -> ON")
        else:
            self.peltier.off()
            print("[HW] peltier (GPIO20) -> OFF")

    def set_swing(self, enabled: bool):
        self.state["swingOn"] = enabled
        print(f"[HW] swing -> {enabled}")
        self.update_swing_task()

    def update_swing_task(self):
        if self.state["swingOn"]:
            if not self.swing_task or self.swing_task.done():
                self.swing_task = asyncio.create_task(self.swing_loop())
        else:
            if self.swing_task and not self.swing_task.done():
                self.swing_task.cancel()

    async def swing_loop(self):
        if not self.servo_ok:
            return

        try:
            while self.state["swingOn"]:
                await self.servo_ramp(SERVO_MIN, SERVO_MAX)
                await self.servo_ramp(SERVO_MAX, SERVO_MIN)

            servo_set_ns(SERVO_MID)

        except asyncio.CancelledError:
            try:
                servo_set_ns(SERVO_MID)
            except Exception:
                pass
            raise

    async def servo_ramp(self, start, end, seconds=2.5, hz=80):
        steps = max(1, int(seconds * hz))
        delay = seconds / steps

        for i in range(steps + 1):
            if not self.state["swingOn"]:
                return

            pulse = int(start + (end - start) * (i / steps))
            servo_set_ns(pulse)
            await asyncio.sleep(delay)

    def shutdown(self):
        self.cancel_task(self.swing_task)
        self.cancel_task(self.dht_init_task)

        self.close_output(self.peltier)
        self.close_output(self.hot_fan)

        try:
            self.cold_fan.value = 0.0
            self.cold_fan.close()
        except Exception:
            pass

        servo_disable()

        try:
            if self.dht:
                self.dht.exit()
        except Exception:
            pass

    @staticmethod
    def cancel_task(task):
        try:
            if task and not task.done():
                task.cancel()
        except Exception:
            pass

    @staticmethod
    def close_output(device):
        try:
            device.off()
            device.close()
        except Exception:
            pass


def read_other_temps():
    return None, None


def build_telemetry(hw: Hardware):
    hot_temp, cold_temp = read_other_temps()

    return {
        "type": "telemetry",
        "ts": now_ms(),
        "hotSideTempC": hot_temp,
        "coldSideTempC": cold_temp,
        "coldFanPwm": hw.state["coldFanPwm"],
        "hotFanPwm": hw.state["hotFanPwm"],
        "peltierOn": hw.state["peltierOn"],
        "swingOn": hw.state["swingOn"],
        "fault": None,
    }


async def telemetry_loop(ws, hw: Hardware):
    while True:
        ambient_temp, humidity = await hw.read_dht22()

        msg = build_telemetry(hw)
        msg["ambientTempC"] = ambient_temp
        msg["humidityPct"] = humidity

        await ws.send(json.dumps(msg))
        print("[NET] sent telemetry")

        await asyncio.sleep(TELEMETRY_INTERVAL_SEC)


def apply_command(payload, hw: Hardware):
    if payload.get("swingOn") is not None:
        hw.set_swing(bool(payload["swingOn"]))

    if payload.get("coldFanPwm") is not None:
        value = clamp_int(payload["coldFanPwm"])
        if value is not None:
            hw.set_cold_fan_pwm(value)

    if payload.get("hotFanPwm") is not None:
        value = clamp_int(payload["hotFanPwm"])
        if value is not None:
            hw.set_hot_fan_pwm(value)

    if payload.get("peltierOn") is not None:
        hw.set_peltier(bool(payload["peltierOn"]))


async def receiver_loop(ws, hw: Hardware):
    async for raw in ws:
        print("[NET] received:", raw)

        try:
            data = json.loads(raw)
        except Exception:
            continue

        if data.get("type") == "command":
            apply_command(data.get("payload") or {}, hw)


async def connect_loop(hw: Hardware):
    backoff = 1

    while True:
        try:
            print(f"[NET] connecting -> {BACKEND_WS}")

            async with websockets.connect(
                BACKEND_WS,
                ping_interval=20,
                ping_timeout=20,
                open_timeout=30,
            ) as ws:
                print("[NET] connected")
                backoff = 1

                await asyncio.gather(
                    telemetry_loop(ws, hw),
                    receiver_loop(ws, hw),
                )

        except Exception as e:
            print("[NET] disconnected:", type(e).__name__, repr(e))
            print(f"[NET] retry in {backoff}s...")

            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 30)


async def main():
    hw = Hardware()

    try:
        await hw.async_init()
        await connect_loop(hw)
    finally:
        hw.shutdown()


if __name__ == "__main__":
    asyncio.run(main())
