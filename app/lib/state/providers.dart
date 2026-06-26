import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_controller.dart';

final appControllerProvider = Provider<AppController>((ref) {
  final c = AppController();
  ref.onDispose(c.dispose);
  c.init();
  return c;
});
