import 'dart:convert';

class EqPreset {
  final String id;
  final String name;
  final List<double> gains; // Slider values in dB

  EqPreset({required this.id, required this.name, required this.gains});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'gains': gains};
  }

  factory EqPreset.fromMap(Map<String, dynamic> map) {
    return EqPreset(
      id: map['id'],
      name: map['name'],
      gains: List<double>.from(map['gains']),
    );
  }

  String toJson() => json.encode(toMap());
  factory EqPreset.fromJson(String source) =>
      EqPreset.fromMap(json.decode(source));

  // Helper for equality checks
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EqPreset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
