import 'package:flutter/widgets.dart';

import '../../../shared/models/character.dart';
import '../../../shared/models/image_style.dart';
import '../presentation/widgets/elumi_choice_sheets.dart';

/// 다른 기능이 그림 방식 바꾸기 시트를 여는 입구 (presentation 을 직접 알지 않게, tool/check_layer_imports.dart)

/// 그림 방식 시트 > 고른 방식 (지금 값 그대로·닫음은 null) (#1287 일과 만들기 알약)
Future<ImageStyle?> openImageStyleSheet(
  BuildContext context, {
  required ImageStyle current,
  required CardCharacter character,
}) =>
    showElumiImageStyleSheet(context, current: current, character: character);
