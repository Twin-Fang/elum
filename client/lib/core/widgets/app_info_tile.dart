import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_status/app_status_repository.dart';
import 'settings_tile.dart';

/// `앱 정보` 줄. 오른쪽에 `v1.44.0` 처럼 앱 버전을 보여주고, 누를 수는 없다.
///
/// 보호자 설정과 이룸이 휴대폰 설정 시트가 함께 쓴다 (#485). 두 곳이 각자 그리면
/// 한쪽만 고쳐져 어긋난다.
///
/// 버전을 못 읽으면(플러그인 미등록·테스트 환경) 값 자리만 비운다. 사용자가 할 수
/// 있는 일이 없으므로 오류로 보여줄 이유가 없고, 줄은 남겨 자리가 흔들리지 않게 한다.
class AppInfoTile extends ConsumerWidget {
  const AppInfoTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref
        .watch(appVersionProvider)
        .maybeWhen(data: (value) => value, orElse: () => '');

    return SettingsTile(
      label: '앱 정보',
      onTap: null,
      valueText: version.isEmpty ? '' : 'v$version',
    );
  }
}
