import '../core/utils/parsers.dart';

class DailyStat {
  final DateTime day;
  final double? minAmbientTempC;
  final double? maxAmbientTempC;

  DailyStat({
    required this.day,
    required this.minAmbientTempC,
    required this.maxAmbientTempC,
  });

  factory DailyStat.fromJson(Map<String, dynamic> j) {
    final raw = (j["day"] ?? "").toString().split("-");
    final day = raw.length == 3
        ? DateTime(
            int.tryParse(raw[0]) ?? DateTime.now().year,
            int.tryParse(raw[1]) ?? 1,
            int.tryParse(raw[2]) ?? 1,
          )
        : DateTime.now();

    return DailyStat(
      day: day,
      minAmbientTempC: asDouble(j["minAmbientTempC"]),
      maxAmbientTempC: asDouble(j["maxAmbientTempC"]),
    );
  }
}