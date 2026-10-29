import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../../core/widgets/character_badge.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/settings_group.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/character.dart';
import '../../../core/widgets/routine_rename_sheet.dart';
import '../../member/application/member_providers.dart';
import '../../member/application/elumi_info_editor.dart';
import '../domain/profile_summary.dart';
import 'widgets/elumi_choice_sheets.dart';

/// 이룸이 정보 고치기: 캐릭터 배지 > 이름·캐릭터·그림 방식 줄 > 줄마다 시트로 바꾸기 (#660)
///
/// 내정보 이룸이 줄의 연필에서 들어옴. 고른 이룸이가 아니어도 [profileId] 이룸이에 저장
class ElumiInfoScreen extends ConsumerStatefulWidget {
  const ElumiInfoScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ElumiInfoScreen> createState() => _ElumiInfoScreenState();
}

/// 저장 중인 줄 (그 줄에만 스피너)
enum _ElumiInfoField { name, character, imageStyle }

class _ElumiInfoScreenState extends ConsumerState<ElumiInfoScreen>
    with BusyStateMixin<ElumiInfoScreen> {
  /// 이름 글자 수 상한 (보호자 표시 이름과 같은 20자)
  static const _nicknameMaxLength = 20;

  /// 배지 한 변 · 배지와 줄 묶음 사이
  static const _badgeSize = 88.0;
  static const _badgeToGroupGap = 24.0;

  /// 첫 줄 위치: 설정 묶음 화면과 같은 자리
  static const _contentTop = 24.0;

  ElumiInfoEditor get _editor => ref.read(elumiInfoEditorProvider);

  /// 이름: 시트 > 저장
  Future<void> _rename(ProfileSummary profile) async {
    final nickname = await showRoutineRenameSheet(
      context,
      currentTitle: profile.nickname ?? '',
      maxLength: _nicknameMaxLength,
      hintText: context.l10n.onboardingNameHint,
    );
    if (nickname == null || !mounted) return;
    await _save(
      _ElumiInfoField.name,
      () => _editor.rename(profile.id, nickname),
    );
  }

  /// 캐릭터: 시트 > 저장
  Future<void> _changeCharacter(ProfileSummary profile) async {
    final character = await showElumiCharacterSheet(
      context,
      current: _characterOf(profile),
    );
    if (character == null || !mounted) return;
    await _save(
      _ElumiInfoField.character,
      () => _editor.changeCharacter(profile.id, character),
    );
  }

  /// 그림 방식: 시트 > 저장
  Future<void> _changeImageStyle(ProfileSummary profile) async {
    final style = await showElumiImageStyleSheet(
      context,
      current: profile.imageStyle,
      character: _characterOf(profile),
    );
    if (style == null || !mounted) return;
    await _save(
      _ElumiInfoField.imageStyle,
      () => _editor.changeImageStyle(profile.id, style),
    );
  }

  /// 저장 공통: 진행 중이면 무시 > 저장 > 성공 알림 / 실패 팝업 (에러 코드 포함)
  Future<void> _save(
    _ElumiInfoField field,
    Future<AppFailure?> Function() save,
  ) async {
    // 결과가 null(성공)과 구분되도록 레코드로 감쌈. 바깥이 null 이면 이미 저장 중
    final saveAttempt = await runBusy(() async => (await save(),), key: field);
    if (saveAttempt == null || !mounted) return;
    final failure = saveAttempt.$1;
    if (failure == null) {
      showElumToastOn(
        ScaffoldMessenger.maybeOf(context),
        context.l10n.elumiInfoSaved,
      );
      return;
    }
    await showFailure(
      context,
      failure,
      title: context.l10n.elumiInfoSaveFailedTitle,
      fallback: context.l10n.elumiInfoSaveFailedFallback,
      fallbackCode: 'E-ELUMI-SAVE',
    );
  }

  /// 모르는 캐릭터 값이면 첫 캐릭터 (화면이 죽지 않게)
  static CardCharacter _characterOf(ProfileSummary profile) =>
      CardCharacter.fromApiValue(profile.character) ??
      CardCharacter.values.first;

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(memberProvider);
    final profile = member.value?.profiles
        .where((p) => p.id == widget.profileId)
        .firstOrNull;

    return ElumScaffold(
      onBack: context.popOrHome,
      title: profile == null
          ? null
          : context.l10n.elumiInfoTitle(profile.displayName),
      backTop: 67,
      horizontalPadding: 16,
      child: _content(member, profile),
    );
  }

  /// 본문: 처음 받는 중 > 로딩 · 못 받음/목록에 없음(나갔거나 지워짐) > 재시도 · 그 외 정보 줄
  Widget _content(AsyncValue<Object?> member, ProfileSummary? profile) {
    if (profile == null) {
      if (member.isLoading && member.value == null) {
        return const ElumStateBody.loading();
      }
      return ElumStateBody(
        child: ElumErrorView(
          message: context.l10n.elumiInfoNotFound,
          errorCode: 'E-ELUMI-LOAD',
          onRetry: () => ref.invalidate(memberProvider),
          compact: true,
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: _contentTop.h, bottom: _contentTop.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CharacterBadge(
              character: _characterOf(profile),
              badgeSize: _badgeSize,
            ),
          ),
          SizedBox(height: _badgeToGroupGap.h),
          SettingsGroup(
            children: [
              _fieldTile(
                field: _ElumiInfoField.name,
                label: context.l10n.elumiInfoName,
                value: profile.displayName,
                onTap: () => _rename(profile),
              ),
              _fieldTile(
                field: _ElumiInfoField.character,
                label: context.l10n.elumiInfoCharacter,
                value: _characterOf(profile).displayName,
                onTap: () => _changeCharacter(profile),
              ),
              _fieldTile(
                field: _ElumiInfoField.imageStyle,
                label: context.l10n.imageStyleTitle,
                value: profile.imageStyle.label,
                onTap: () => _changeImageStyle(profile),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 정보 한 줄 (`이름  하늘이 ›`). 저장 중이면 그 줄만 스피너, 모든 줄 누름 막음
  Widget _fieldTile({
    required _ElumiInfoField field,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return SettingsTile(
      isInCard: true,
      label: label,
      valueText: value,
      showChevronWithValue: true,
      loading: isBusy(field),
      onTap: busy ? null : onTap,
    );
  }
}
