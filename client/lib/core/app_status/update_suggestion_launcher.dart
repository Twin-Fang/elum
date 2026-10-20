import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_suggestion.dart';

/// 이룸이 홈을 감싸 업데이트 권유를 띄움 (첫 프레임 뒤, 하루 한 번)
/// 보호자 홈은 공지와 차례를 맞춰야 해서 GuardianNoticeLauncher 가 직접 부름
class UpdateSuggestionLauncher extends ConsumerStatefulWidget {
  const UpdateSuggestionLauncher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateSuggestionLauncher> createState() =>
      _UpdateSuggestionLauncherState();
}

class _UpdateSuggestionLauncherState
    extends ConsumerState<UpdateSuggestionLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showUpdateSuggestionIfNeeded(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
