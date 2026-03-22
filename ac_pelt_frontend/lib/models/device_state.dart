import '../core/utils/parsers.dart';

class DeviceState {
  bool deviceOnline = false;
  double? ambientTempC;
  double? humidityPct;
  int? coldFanPwm;
  int? hotFanPwm;
  bool? peltierOn;
  bool? swingOn;
  int? ts;

  void updateFromJson(Map<String, dynamic> s) {
    deviceOnline = asBool(s['deviceOnline']);
    ambientTempC = asDouble(s['ambientTempC']);
    humidityPct = asDouble(s['humidityPct']);
    coldFanPwm = asInt(s['coldFanPwm']);
    hotFanPwm = asInt(s['hotFanPwm']);
    peltierOn = s['peltierOn'] is bool ? s['peltierOn'] as bool : null;
    swingOn = s['swingOn'] is bool ? s['swingOn'] as bool : null;
    ts = asInt(s['ts']);
  }
}