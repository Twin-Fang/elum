import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/shared/models/credit_usage.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/credit_fixtures.dart';
import 'helpers/fake_dio.dart';

void main() {
  group('CreditSummary.fromJson — 서버 필드 그대로', () {
    test('정상 응답을 읽는다', () {
      final s = CreditSummary.fromJson(creditJson());

      expect(s.enabled, isTrue);
      expect(s.available, 72);
      expect(s.weeklyGrant, 100);
      expect(s.bonus, 0);
      expect(s.used, 28);
      expect(s.routineTextCost, 1);
      expect(s.cardImageCost, 1);
      expect(s.maxCardsPerRoutine, 10);
      expect(s.nextResetAt, DateTime(2026, 9, 28));
      expect(s.canStartRoutine, isTrue);
      expect(s.inProgress, isEmpty);
    });

    test('진행 중 작업을 읽는다', () {
      final s = CreditSummary.fromJson(creditJson(inProgress: [
        {'jobId': 'j1', 'kind': 'ROUTINE_CREATE', 'startedAt': '2026-09-24T10:00:00'},
        // 모양이 어긋난 항목은 버린다 — 한 줄 때문에 카드 전체가 실패하면 안 된다
        'garbage',
      ]));

      expect(s.inProgress, hasLength(1));
      expect(s.inProgress.single.kind, 'ROUTINE_CREATE');
      expect(s.isGeneratingRoutine, isTrue);
    });

    // 0 으로 채워 넣으면 "크레딧이 없다" 는 거짓말이 된다 (Review Focus 5).
    for (final key in ['available', 'weeklyGrant', 'nextResetAt', 'canStartRoutine']) {
      test('$key 가 없으면 FormatException — 0 으로 대신하지 않는다', () {
        final json = creditJson()..remove(key);
        expect(() => CreditSummary.fromJson(json), throwsFormatException);
      });
    }

    test('숫자 자리에 글자가 오면 FormatException', () {
      final json = creditJson()..['available'] = 'many';
      expect(() => CreditSummary.fromJson(json), throwsFormatException);
    });

    test('enabled 가 없으면 FormatException', () {
      final json = creditJson()..remove('enabled');
      expect(() => CreditSummary.fromJson(json), throwsFormatException);
    });

    test('꺼져 있으면 나머지 필드가 비어도 읽는다', () {
      final s = CreditSummary.fromJson(const {'enabled': false});
      expect(s.enabled, isFalse);
    });
  });

  group('파생 값', () {

    test('0 이면 소진이다', () {
      expect(CreditSummary.fromJson(creditJson(available: 0)).isExhausted, isTrue);
      expect(CreditSummary.fromJson(creditJson(available: 1)).isExhausted, isFalse);
    });

    test('남은 비율은 주간 + 보너스 대비이고 0~1 로 묶인다', () {
      expect(CreditSummary.fromJson(creditJson(available: 72)).remainingRatio, closeTo(0.72, 1e-9));
      expect(
        CreditSummary.fromJson(creditJson(available: 120, bonus: 20)).remainingRatio,
        closeTo(1.0, 1e-9),
      );
      expect(
        CreditSummary.fromJson(creditJson(available: 0, weeklyGrant: 0)).remainingRatio,
        0,
      );
    });

    test('다음 초기화를 `9월 28일(월) 0시` 로 적는다', () {
      expect(CreditSummary.fromJson(creditJson()).resetLabel, '9월 28일(월) 0시');
    });

    // 시간대가 있는 값을 기기 시간대로 바꿔 적는다 (#421 ③). 시간대 없는 값만 쓰면
    // 뉴욕 시간대 기기에서도 `9월 28일(월) 0시` 로 나왔다 — 실제는 27일(일) 오전 11시.
    test('시간대가 있는 초기화 시각을 쓰고 기기 시간대로 바꿔 적는다 (#421)', () {
      final s = CreditSummary.fromJson({
        ...creditJson(),
        'nextResetAtOffset': '2026-09-28T00:00:00+09:00',
      });

      // 한국 월요일 0시 = UTC 일요일 15시. 같은 순간이어야 한다.
      expect(s.nextResetAt!.isAtSameMomentAs(DateTime.utc(2026, 9, 27, 15)), isTrue);
      // 적는 것은 기기 시간대 기준이다 — 이 테스트가 어느 시간대에서 돌든 맞아야 한다.
      final local = DateTime.utc(2026, 9, 27, 15).toLocal();
      const days = ['월', '화', '수', '목', '금', '토', '일'];
      final minute = local.minute == 0 ? '' : ' ${local.minute}분';
      expect(
        s.resetLabel,
        '${local.month}월 ${local.day}일(${days[local.weekday - 1]}) ${local.hour}시$minute',
      );
    });

    test('시간대 있는 값이 없는 옛 서버 응답은 기존 값을 쓴다', () {
      expect(CreditSummary.fromJson(creditJson()).nextResetAt, DateTime(2026, 9, 28));
    });
  });

  group('CreditUsage — 생성 응답의 credit', () {
    test('읽는다', () {
      final u = CreditUsage.tryParse(const {
        'cardCount': 5,
        'imageCount': 4,
        'charged': 5,
        'balanceAfter': 67,
      });
      expect(u, const CreditUsage(cardCount: 5, imageCount: 4, charged: 5, balanceAfter: 67));
    });

    test('없거나 모양이 다르면 null — 줄을 안 그린다', () {
      expect(CreditUsage.tryParse(null), isNull);
      expect(CreditUsage.tryParse(const {'cardCount': 5}), isNull);
      expect(CreditUsage.tryParse('x'), isNull);
    });

    test('Routine.fromJson 이 credit 을 싣는다', () {
      final r = Routine.fromJson(const {
        'id': 'r1',
        'credit': {'cardCount': 5, 'imageCount': 4, 'charged': 5, 'balanceAfter': 67},
      });
      expect(r.creditUsage?.balanceAfter, 67);
      expect(Routine.fromJson(const {'id': 'r1'}).creditUsage, isNull);
    });
  });

  group('CreditRepository.getMine', () {
    Future<CreditSummary> fetch(Map<String, Object?> routes) {
      final container = ProviderContainer(overrides: [fakeDioOverride(routes)]);
      addTearDown(container.dispose);
      return container.read(creditRepositoryProvider).getMine();
    }

    test('성공하면 요약을 준다', () async {
      final s = await fetch({'GET /api/credits/me': creditJson(available: 3)});
      expect(s.available, 3);
    });

    test('서버가 실패하면 AppFailure 를 던진다', () async {
      await expectLater(
        fetch(const {'GET /api/credits/me': FakeHttpError(503, errorCode: 'AI_CREDIT_UNAVAILABLE')}),
        throwsA(isA<AppFailure>()),
      );
    });

    test('형식이 다르면 AppFailure 를 던진다 — 0 을 그리지 않는다', () async {
      await expectLater(
        fetch(const {'GET /api/credits/me': {'enabled': true}}),
        throwsA(isA<AppFailure>().having((f) => f.badgeOr('E-CREDIT'), 'badge', 'E-CREDIT')),
      );
    });

    test('오프라인이면 AppFailure(offline)', () async {
      await expectLater(
        fetch(const {'GET /api/credits/me': FakeOffline()}),
        throwsA(isA<AppFailure>().having((f) => f.fault, 'fault', NetworkFault.offline)),
      );
    });
  });
}
