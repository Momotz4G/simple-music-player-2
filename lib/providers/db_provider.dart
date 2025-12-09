import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/db_service.dart';

// This provider gives other parts of your app access to the database
final dbServiceProvider = Provider<DBService>((ref) {
  return DBService();
});
