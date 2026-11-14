import 'package:go_router/go_router.dart';

import '../../features/lock_screen/presentation/lock_screen_preview_page.dart';
import '../../features/lock_screen/presentation/lock_screen_settings_page.dart';
import '../layout/adaptive_page_frame.dart';
import '../layout/screen_layout_kind.dart';
import 'app_transitions.dart';
import 'routes.dart';

/// 잠금화면 카드 설정 · 미리 보기 (보호자 · 이룸이 기기 공통, 이룸이 기기는 설정에서 보호자 암호 확인 뒤 염)
List<RouteBase> lockScreenRoutes() => [
  GoRoute(
    path: Routes.lockScreenSettings,
    pageBuilder: (context, state) =>
        slidePage(state, const LockScreenSettingsPage()),
  ),
  GoRoute(
    path: Routes.lockScreenPreview,
    builder: (context, state) => const AdaptivePageFrame(
      kind: ScreenLayoutKind.phoneColumn,
      child: LockScreenPreviewPage(),
    ),
  ),
];
