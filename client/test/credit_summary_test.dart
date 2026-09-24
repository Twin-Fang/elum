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
    test('적음 기준은 일과 글 + 최대 카드 수 × 그림 단가 = 11', () {
      expect(CreditSummary.fromJson(creditJson(available: 11)).isLow, isFalse);
      expect(CreditSummary.fromJson(creditJson(available: 10)).isLow, isTrue);
      expect(CreditSummary.fromJson(creditJson(available: 0)).isLow, isTrue);
    });

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
