import 'package:flutter_riverpod/legacy.dart';
import '../services/locale_service.dart';

/// Provider for locale service
final localeServiceProvider = ChangeNotifierProvider<LocaleService>((ref) {
  return LocaleService();
});

