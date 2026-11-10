import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/layout/share_origin.dart';
import '../../../../core/router/pop_or_home.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_scaffold.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../../../core/widgets/elum_text_link.dart';
import '../../../../core/widgets/pro_teaser.dart';
import '../../../../core/widgets/pro_upsell_button.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../member/application/plan_access.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/domain/plan_benefit.dart';
import '../../application/guardian_child_identity.dart';
import '../../application/weekly_report_providers.dart';
import '../../data/card_export_files.dart';
import '../../domain/weekly_report.dart';
import '../pro_teaser_samples.dart';
import 'weekly_report_past_weeks_sheet.dart';
import 'weekly_report_save_sheet.dart';
import 'weekly_report_sections.dart';
import 'weekly_report_share_capture.dart';
import 'weekly_report_week_picker.dart';

/// 화면 에러 코드 (서버 코드가 없을 때 보임)
abstract final class WeeklyReportErrorCode {
  static const load = 'E-WEEKLY-REPORT';
  static const share = 'E-WEEKLY-REPORT-SHARE';
}

/// 주간 리포트 (Pro): 주 고르기 > 정리 글 · 숫자 · 요일별 · 일과별 · 남은 카드 > 저장하기 · 지난 리포트 보기
///
/// 상태: 불러오는 중 / 보낸 일과 0건(빈 상태) / 실패(에러 코드 + 다시 하기) / 리포트.
/// Pro 가 아님: 미리 보기 주(서버가 정함)는 실제 리포트, 그 밖의 주는 판매 중이면 Pro 미리 보기 판 · 아니면 안내만.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key, this.initialWeekStart});

  /// 알림에서 들어올 때 먼저 보여 줄 주 (그 날이 든 주). null 이면 이번 주
  final DateTime? initialWeekStart;

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  static const _backTop = ElumScaffold.settingsBackTop;
  static const _horizontalPadding = 16.0;
  static const _pickerTopGap = 8.0;
  static const _sectionGap = 16.0;
  static const _scrollBottomGap = 24.0;
  static const _files = CardExportFiles();

  bool _isSaving = false;

  // 시작 주(알림에서 온 주)를 반영하기 전에는 이번 주 리포트를 받지 않음
  late bool _isStartWeekApplied = widget.initialWeekStart == null;

  // 알림 주 · 사용자가 고른 주 · 미리 보기 주로 이미 맞췄으면 다시 옮기지 않음
  late bool _hasWeekBeenChosen = widget.initialWeekStart != null;

  @override
  void initState() {
    super.initState();
    // provider 는 빌드 중 못 바꾸므로 첫 프레임 뒤에 반영
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initialWeekStart = widget.initialWeekStart;
      if (initialWeekStart != null) {
        ref.read(weeklyReportWeekProvider.notifier).showWeekOf(initialWeekStart);
        setState(() => _isStartWeekApplied = true);
      } else if (!ref.read(planAccessProvider).canViewWeeklyReport) {
        _showFreePreviewWeek(ref.read(weeklyReportFreePreviewWeekProvider));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isFullAccess = ref.watch(planAccessProvider.select((access) => access.canViewWeeklyReport));
    final weekStart = ref.watch(weeklyReportWeekProvider);
    final weekNotifier = ref.read(weeklyReportWeekProvider.notifier);
    final freePreviewWeekStart = isFullAccess ? null : ref.watch(weeklyReportFreePreviewWeekProvider);
    if (!isFullAccess) ref.listen(weeklyReportFreePreviewWeekProvider, (_, next) => _showFreePreviewWeek(next));
    final isFreePreview = freePreviewWeekStart != null && freePreviewWeekStart == weekStart;
    final isViewable = isFullAccess || isFreePreview;
    final reportAsync = isViewable && _isStartWeekApplied ? ref.watch(weeklyReportProvider(weekStart)) : null;
    final report = reportAsync?.value;
    final canSave = report != null && report.hasRecords && !reportAsync!.isLoading;

    return ElumScaffold(
      onBack: context.popOrHome,
      title: l10n.weeklyReportTitle,
      backTop: _backTop,
      horizontalPadding: _horizontalPadding,
      bottomButton: canSave
          ? ElumButton(
              label: l10n.weeklyReportSave,
              loading: _isSaving,
              onPressed: _isSaving ? null : () => _save(report),
            )
          : null,
      belowButton: isViewable ? ElumTextLink(label: l10n.weeklyReportPastReports, onTap: _openPastWeeks) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: _pickerTopGap.h),
          if (isFullAccess || freePreviewWeekStart != null) ...[
            WeeklyReportWeekPicker(
              weekStart: weekStart,
              isCurrentWeek: !weekNotifier.canShowNextWeek,
              onPreviousWeek: () {
                _hasWeekBeenChosen = true;
                weekNotifier.showPreviousWeek();
              },
              onNextWeek: () {
                _hasWeekBeenChosen = true;
                weekNotifier.showNextWeek();
              },
            ),
            SizedBox(height: _sectionGap.h),
          ],
          Expanded(child: _body(context, reportAsync, weekStart, isViewable: isViewable, isFreePreview: isFreePreview)),
        ],
      ),
    );
  }

  /// 미리 보기 주가 정해지면 그 주로 (알림·사용자가 주를 정했으면 그대로)
  void _showFreePreviewWeek(DateTime? freePreviewWeekStart) {
    if (freePreviewWeekStart == null || _hasWeekBeenChosen) return;
    _hasWeekBeenChosen = true;
    ref.read(weeklyReportWeekProvider.notifier).showWeekOf(freePreviewWeekStart);
  }

  Widget _body(
    BuildContext context,
    AsyncValue<WeeklyReport>? reportAsync,
    DateTime weekStart, {
    required bool isViewable,
    required bool isFreePreview,
  }) {
    final l10n = context.l10n;
    if (isViewable && reportAsync == null) return const ElumStateBody.loading();
    // Pro 가 아님: 앱 판정 또는 서버 Pro 거절(WEEKLY_REPORT_NOT_ALLOWED) > 실패 대신 미리 보기·안내
    final isNotIncluded = !isViewable || (reportAsync?.hasError == true && isProOnlyRejection(reportAsync?.error));
    if (isNotIncluded) {
      if (ref.watch(planAccessProvider).shouldPromoteBenefit(PlanBenefit.weeklyReport)) {
        return SingleChildScrollView(
          child: ProTeaser(
            title: l10n.proTeaserWeeklyReportTitle,
            benefit: l10n.proTeaserWeeklyReportBenefit,
            actions: watchProUpsellActions(context, ref, highlight: PlanBenefit.weeklyReport),
            child: ProTeaserSamples.weeklyReportSections(context),
          ),
        );
      }
      return ElumStateBody(child: ElumErrorView(message: l10n.weeklyReportNotIncluded, compact: true));
    }
    return switch (reportAsync) {
      AsyncData(value: final report) when !report.hasRecords => const ElumStateBody(child: _EmptyBody()),
      AsyncData(value: final report) => _reportBody(context, report, isFreePreview: isFreePreview),
      AsyncError(:final error) => ElumStateBody(
        child: ElumErrorView.failure(
          error,
          fallback: l10n.weeklyReportLoadFailed,
          fallbackCode: WeeklyReportErrorCode.load,
          onRetry: () => ref.invalidate(weeklyReportProvider(weekStart)),
        ),
      ),
      _ => const ElumStateBody.loading(),
    };
  }

  Widget _reportBody(BuildContext context, WeeklyReport report, {required bool isFreePreview}) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isFreePreview) ...[
            _FreePreviewNote(actions: watchProUpsellActions(context, ref, highlight: PlanBenefit.weeklyReport)),
            SizedBox(height: _sectionGap.h),
          ],
          WeeklyReportSections(report: report),
          SizedBox(height: _scrollBottomGap.h),
        ],
      ),
    );
  }

  /// 지난 리포트 시트 > 고른 주로 이동
  Future<void> _openPastWeeks() async {
    final selectedWeekStart = await showWeeklyReportPastWeeksSheet(context);
    if (selectedWeekStart == null || !mounted) return;
    _hasWeekBeenChosen = true;
    ref.read(weeklyReportWeekProvider.notifier).showWeekOf(selectedWeekStart);
  }

  // 저장 모양 고르기 > 한 장 굽기 > PNG 또는 A4 PDF > 공유 시트
  Future<void> _save(WeeklyReport report) async {
    final l10n = context.l10n;
    final format = await showWeeklyReportSaveSheet(context);
    if (format == null || !mounted) return;
    final origin = shareOriginOf(context);
    final elumiName = ref.read(guardianChildIdentityProvider).name;
    setState(() => _isSaving = true);
    try {
      final png = await captureWeeklyReportPng(context: context, report: report, elumiName: elumiName);
      final stem = '${exportFileStem(l10n.weeklyReportShareTitle(elumiName))}_${_dateStamp(report.weekStart)}';
      switch (format) {
        case WeeklyReportSaveFormat.pdf:
          final pdf = await _files.buildA4Pdf([png]);
          await _files.share(
            files: [(fileName: '$stem.pdf', bytes: pdf, mimeType: 'application/pdf')],
            sharePositionOrigin: origin,
          );
        case WeeklyReportSaveFormat.image:
          await _files.share(
            files: [(fileName: '$stem.png', bytes: png, mimeType: 'image/png')],
            sharePositionOrigin: origin,
          );
      }
    } on Object catch (error) {
      if (!mounted) return;
      await showFailure(
        context,
        error,
        fallback: l10n.weeklyReportShareFailed,
        fallbackCode: WeeklyReportErrorCode.share,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 주 시작 > `20261102` (파일 이름 끝)
  static String _dateStamp(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
}

/// Free 미리 보기 주 위 한 줄 + Pro 안내 버튼
class _FreePreviewNote extends StatelessWidget {
  const _FreePreviewNote({required this.actions});

  final ProUpsellActions actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          context.l10n.weeklyReportFreePreviewNote,
          textAlign: TextAlign.center,
          style: context.typo.creditBody.copyWith(color: context.colors.textSecondary),
        ),
        ProUpsellButton(
          style: ProUpsellStyle.link,
          freeTrialLabel: actions.freeTrialLabel,
          onTap: actions.onStart,
        ),
      ],
    );
  }
}

/// 보낸 일과 0건: 글만 (보호자 빈 상태는 그림 없음)
class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.weeklyReportEmptyTitle,
          textAlign: TextAlign.center,
          style: context.typo.creditHistoryRowTitle.copyWith(color: colors.settingsCardLabel),
        ),
        SizedBox(height: context.space.xs),
        Text(
          context.l10n.weeklyReportEmptyBody,
          textAlign: TextAlign.center,
          style: context.typo.creditHistoryRowDetail.copyWith(color: colors.settingsGroupLabel),
        ),
      ],
    );
  }
}
