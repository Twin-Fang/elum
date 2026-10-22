import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/routine.dart';

/// 묶음 아이콘 안 일과 그림 2×2 (일과관리 폴더 칸과 같은 그림)
typedef RoutineGroupPreviewBuilder = Widget Function(List<Routine> routines);

/// 다른 기능(이야기 가져오기 시트)이 일과관리 그림을 그리는 연결 고리
/// 그림 위젯이 guardian 화면 층에 있어 core 에 두고, 실제 구현은 main 이 끼움 (빈 칸이 기본값)
final routineGroupPreviewBuilderProvider = Provider<RoutineGroupPreviewBuilder>(
  (ref) =>
      (_) => const SizedBox.shrink(),
);
