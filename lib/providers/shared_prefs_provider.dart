import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This provider is designed to throw an UnimplementedError if accessed
// before it is overridden with a real SharedPreferences instance in main.dart.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized in main.dart');
});
