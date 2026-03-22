import '../core/utils/parsers.dart';
import 'rule.dart';

class Profile {
  final String id;
  String name;
  bool enabled;
  List<Rule> rules;

  Profile({
    required this.id,
    required this.name,
    required this.enabled,
    required this.rules,
  });

  factory Profile.fromJson(Map<String, dynamic> j) {
    return Profile(
      id: (j["id"] ?? "").toString(),
      name: (j["name"] ?? "").toString(),
      enabled: asBool(j["enabled"]),
      rules: ((j["rules"] as List<dynamic>? ?? []))
          .map((e) => Rule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "enabled": enabled,
        "rules": rules.map((r) => r.toJson()).toList(),
      };
}