import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_status/update_suggestion.dart';
import '../../../core/storage/local_storage.dart';
import '../application/push_permission_prompt.dart';

/// 이룸이 홈을 감싸 첫 프레임 뒤 차례로 띄움: 업데이트 권유(하루 한 번) > 알림 켜기 권하기(이룸이 기기만, 7일마다)
/// 연결 직후 처음 들어오면 기록이 없어 바로 권함. 보호자 기기가 이룸이 화면을 보여 줄 때는 권하지 않음
class ElumiHomeLauncher extends ConsumerStatefulWidget {
  const ElumiHomeLauncher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ElumiHomeLauncher> createState() => _ElumiHomeLauncherState();
}

class _ElumiHomeLauncherState extends ConsumerState<ElumiHomeLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
  }

  Future<void> _launch() async {
    if (!mounted) return;
    await showUpdateSuggestionIfNeeded(context, ref);
    if (!mounted || !ref.read(localStorageProvider).isElumiDevice) return;
    await ref.read(pushPermissionPromptProvider).maybeNudge(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
