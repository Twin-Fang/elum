import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';

/// 일과관리 코치마크가 가리키는 순서 (#834).
enum LibraryCoachStep {
  /// 일과 칸 — 길게 누르면 메뉴
  openMenu,

  /// `+ 일과 만들기` — 새 묶음도 여기서
  createGroup,
}

/// 코치마크 진행 상태. [steps]가 비어 있으면 꺼진 상태다.
class LibraryCoachState {
  const LibraryCoachState({this.steps = const [], this.index = 0});

  final List<LibraryCoachStep> steps;
  final int index;

  bool get isActive => steps.isNotEmpty;
}

final libraryCoachProvider =
    NotifierProvider<LibraryCoachNotifier, LibraryCoachState>(
      LibraryCoachNotifier.new,
    );

/// 일과관리 코치마크의 시작 조건과 진행: 처음 한 번만, 닫으면 끝까지 본 것과 같다
///
/// 홈 코치마크와 같은 원칙 — 못 읽으면 봤다고 치고, 같은 실행에서 두 번 띄우지 않는다.
class LibraryCoachNotifier extends Notifier<LibraryCoachState> {
  bool _shownThisRun = false;

  @override
  LibraryCoachState build() => const LibraryCoachState();

  bool _alreadySeen() {
    try {
      return ref.read(localStorageProvider).isLibraryCoachSeen;
    } catch (e) {
      AppLogger.error('LibraryCoach.read', e);
      return true;
    }
  }

  /// 조건이 맞으면 켠다. 켰으면 true. 가리킬 일과 칸이 없으면 띄우지 않는다
  bool maybeStart({required bool hasTileTarget}) {
    if (!hasTileTarget || state.isActive || _shownThisRun || _alreadySeen()) {
      return false;
    }
    _shownThisRun = true;
    state = const LibraryCoachState(
      steps: [LibraryCoachStep.openMenu, LibraryCoachStep.createGroup],
    );
    return true;
  }

  void next() {
    if (!state.isActive) return;
    if (state.index + 1 >= state.steps.length) {
      finish();
      return;
    }
    state = LibraryCoachState(steps: state.steps, index: state.index + 1);
  }

  /// 끝낸다 — 끝까지 봤든 중간에 닫았든 "본 것"으로 남긴다
  Future<void> finish() async {
    if (!state.isActive) return;
    state = const LibraryCoachState();
    try {
      await ref.read(localStorageProvider).setLibraryCoachSeen(true);
    } catch (e) {
      AppLogger.error('LibraryCoach.write', e);
    }
  }
}
