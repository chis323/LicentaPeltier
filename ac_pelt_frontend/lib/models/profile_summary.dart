import '../core/utils/parsers.dart';

class ProfileSummary {
  final String id;
  final String name;
  final bool enabled;

  ProfileSummary({
    required this.id,
    required this.name,
    required this.enabled,
  });

  factory ProfileSummary.fromJson(Map<String, dynamic> j) {
    return ProfileSummary(
      id: (j["id"] ?? "").toString(),
      name: (j["name"] ?? "").toString(),
      enabled: asBool(j["enabled"]),
    );
  }
}