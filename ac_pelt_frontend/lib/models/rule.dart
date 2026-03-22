import '../core/utils/parsers.dart';

class Rule {
  int dayOfWeek;
  String start;
  String end;
  int coldFanPwm;
  int hotFanPwm;
  bool peltierOn;
  bool swingOn;

  Rule({
    required this.dayOfWeek,
    required this.start,
    required this.end,
    required this.coldFanPwm,
    required this.hotFanPwm,
    required this.peltierOn,
    required this.swingOn,
  });

  factory Rule.fromJson(Map<String, dynamic> j) {
    return Rule(
      dayOfWeek: (j["dayOfWeek"] is num)
          ? (j["dayOfWeek"] as num).toInt()
          : int.tryParse("${j["dayOfWeek"]}") ?? 1,
      start: (j["start"] ?? "08:00").toString(),
      end: (j["end"] ?? "09:00").toString(),
      coldFanPwm: (j["coldFanPwm"] is num) ? (j["coldFanPwm"] as num).toInt() : 0,
      hotFanPwm: (j["hotFanPwm"] is num) ? (j["hotFanPwm"] as num).toInt() : 0,
      peltierOn: asBool(j["peltierOn"]),
      swingOn: asBool(j["swingOn"]),
    );
  }

  Map<String, dynamic> toJson() => {
        "dayOfWeek": dayOfWeek,
        "start": start,
        "end": end,
        "coldFanPwm": coldFanPwm,
        "hotFanPwm": hotFanPwm,
        "peltierOn": peltierOn,
        "swingOn": swingOn,
      };
}