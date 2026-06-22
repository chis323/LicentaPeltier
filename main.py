import asyncio
import json
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
PWM_CHIP = Path("/sys/class/pwm/pwmchip0")
SERVO_CHANNEL = 3
SERVO_PWM = PWM_CHIP / f"pwm{SERVO_CHANNEL}"
SERVO_PERIOD = 20_000_000
SERVO_MIN = 10_000
SERVO_MID = 800_000
SERVO_MAX = 1_500_000
telemetry_counter = 0

def now_ms() -> int:
    global telemetry_counter
    telemetry_counter += int(TELEMETRY_INTERVAL_SEC * 1000)
    return telemetry_counter

def write(path: Path, value):
    path.write_text(str(value))

def clamp_pct(value):
    try:
        return max(0, min(100, int(value)))
    except Exception:
        return None

def servo_set_ns(duty_ns: int):
    duty_ns = max(0, min(SERVO_PERIOD, int(duty_ns)))
    write(SERVO_PWM / "duty_cycle", duty_ns)

async def init_servo_pwm():
    if not SERVO_PWM.exists():
        write(PWM_CHIP / "export", SERVO_CHANNEL)
        await asyncio.sleep(0.1)
    if not SERVO_PWM.exists():
        raise RuntimeError(f"{SERVO_PWM} missing after export")
    write(SERVO_PWM / "enable", 0)
    write(SERVO_PWM / "period", SERVO_PERIOD)
    write(SERVO_PWM / "duty_cycle", SERVO_MID)
    write(SERVO_PWM / "enable", 1)

def disable_servo_pwm():
    try:
        write(SERVO_PWM / "enable", 0)
    except Exception:
        pass

class Hardware:
    def __init__(self):
        self.peltier = DigitalOutputDevice(PELTIERSW_PIN,active_high=True,initial_value=False,)
        self.hot_fan = PWMOutputDevice(FAN_ALWAYS_ON_PIN,active_high=True,initial_value=0.0,)
        self.cold_fan = PWMOutputDevice(FAN_PWM_PIN,active_high=True,initial_value=0.0,)
        self.dht = None
        self.dht_ready = False
        self.servo_ok = False
        self.swing_task: asyncio.Task | None = None
        self.state = {
            "swingOn": False,
            "coldFanPwm": 0,
            "hotFanPwm": 0,
            "peltierOn": False,
        }

    async def async_init(self):
        try:
            await init_servo_pwm()
            self.servo_ok = True
        except PermissionError:
            print("[HW] Servo permission denied. Run with sudo.")
        except Exception as e:
            print("[HW] Servo init failed:", repr(e))
        await self.init_dht()

    async def init_dht(self):
        self.close_dht()
        try:
            print("[HW] Initializing DHT22 on GPIO4...")
            self.dht = adafruit_dht.DHT22(DHT_PIN)
            await asyncio.sleep(2)
            self.dht_ready = True
        except Exception as e:
            print("[HW] DHT init failed:", repr(e))
            self.dht = None
            self.dht_ready = False

    def close_dht(self):
        self.dht_ready = False
        try:
            if self.dht:
                self.dht.exit()
        except Exception:
            pass
        self.dht = None

    async def read_dht22(self):
        if not self.dht or not self.dht_ready:
            return None, None
        try:
            return self.dht.temperature, self.dht.humidity
        except RuntimeError:
            return None, None
        except Exception as e:
            print("[HW] DHT error:", repr(e), "-> reinit")
            await self.init_dht()
            return None, None

    def fail_safe(self):
        self.set_peltier(False)
        self.set_swing(False)
        self.set_cold_fan_pwm(0)
        self.set_hot_fan_pwm(0)

    def set_cold_fan_pwm(self, value: int):
        self.state["coldFanPwm"] = value
        self.cold_fan.value = value / 100

    def set_hot_fan_pwm(self, value: int):
        self.state["hotFanPwm"] = value
        self.hot_fan.value = value / 100

    def set_peltier(self, enabled: bool):
        self.state["peltierOn"] = enabled
        if enabled:
            self.peltier.on()
        else:
            self.peltier.off()

    def set_swing(self, enabled: bool):
        self.state["swingOn"] = enabled
        if enabled:
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
        finally:
            try:
                servo_set_ns(SERVO_MID)
            except Exception:
                pass

    async def servo_ramp(self, start, end, seconds=2.5, hz=80):
        steps = max(1, int(seconds * hz))
        delay = seconds / steps
        for i in range(steps + 1):
            if not self.state["swingOn"]:
                return
            pulse = int(start + (end - start) * i / steps)
            servo_set_ns(pulse)
            await asyncio.sleep(delay)

    def shutdown(self):
        if self.swing_task and not self.swing_task.done():
            self.swing_task.cancel()
        try:
            self.peltier.off()
            self.peltier.close()
        except Exception:
            pass
        try:
            self.hot_fan.off()
            self.hot_fan.close()
        except Exception:
            pass
        try:
            self.cold_fan.value = 0.0
            self.cold_fan.close()
        except Exception:
            pass
        disable_servo_pwm()
        self.close_dht()

def build_telemetry(hw: Hardware, ambient_temp, humidity):
    return {
        "type": "telemetry",
        "ts": now_ms(),
        "ambientTempC": ambient_temp,
        "humidityPct": humidity,
        "coldFanPwm": hw.state["coldFanPwm"],
        "hotFanPwm": hw.state["hotFanPwm"],
        "peltierOn": hw.state["peltierOn"],
        "swingOn": hw.state["swingOn"],
    }

async def telemetry_loop(ws, hw: Hardware):
    while True:
        ambient_temp, humidity = await hw.read_dht22()
        msg = build_telemetry(hw, ambient_temp, humidity)
        await ws.send(json.dumps(msg))
        await asyncio.sleep(TELEMETRY_INTERVAL_SEC)


def apply_command(payload, hw: Hardware):
    if payload.get("swingOn") is not None:
        hw.set_swing(bool(payload["swingOn"]))
    if payload.get("peltierOn") is not None:
        hw.set_peltier(bool(payload["peltierOn"]))
    if payload.get("coldFanPwm") is not None:
        value = clamp_pct(payload["coldFanPwm"])
        if value is not None:
            hw.set_cold_fan_pwm(value)
    if payload.get("hotFanPwm") is not None:
        value = clamp_pct(payload["hotFanPwm"])
        if value is not None:
            hw.set_hot_fan_pwm(value)

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
            async with websockets.connect(BACKEND_WS,ping_interval=20,ping_timeout=20,open_timeout=30,)as ws:
                print("[NET] connected")
                backoff = 1
                await asyncio.gather(telemetry_loop(ws, hw),receiver_loop(ws, hw),)
        except Exception as e:
            print("[NET] disconnected:", type(e).__name__, repr(e))
            hw.fail_safe()
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
