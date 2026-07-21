import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/local_storage.dart';
import 'features/onboarding/application/onboarding_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 저장소는 앱 시작 시 한 번만 초기화하고 provider로 주입한다.
  final storage = await LocalStorage.create();

  runApp(
    ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(storage)],
      child: const ElumApp(),
    ),
  );
}
