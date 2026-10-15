import 'package:elum/features/profile/domain/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// 초대 링크 해석 (#365).
///
/// **링크는 코드를 대신 전달하는 수단일 뿐이다.** 여기서 하는 일은 "이 주소가 초대 링크인가, 그렇다면
/// 코드가 무엇인가"를 가려내는 것이다. 틀린 값을 서버에 보내 시도 한도를 태우지 않으려고 우리가 만들 수
/// 없는 모양은 코드 없음(null)으로 돌린다. 링크는 맞는데 코드가 못 쓸 모양이면 화면이 안내해야 하므로
/// `null` 이 아니라 `InviteLink(code: null)` 이다 — **둘을 구분하는 것이 이 테스트의 핵심이다.**
void main() {
  /// 초대 링크로 인정하고 코드가 [code] 로 나오는가.
  void accepts(String raw, {String code = 'A7K3M9'}) {
    final link = InviteLink.parse(raw);
    expect(link, isNotNull, reason: '초대 링크로 인정해야 한다: $raw');
    expect(link!.code, code, reason: raw);
  }

  /// 초대 링크이긴 한데 쓸 수 있는 코드가 없는가 (화면이 에러 안내를 띄운다).
  void brokenCode(String raw) {
    final link = InviteLink.parse(raw);
    expect(link, isNotNull, reason: '초대 링크로는 인정해야 한다: $raw');
    expect(link!.code, isNull, reason: raw);
  }

  /// 초대 링크가 아닌가 (다른 라우트·로그인 콜백 등은 건드리지 않는다).
  void ignores(Object? raw) {
    expect(InviteLink.parse(raw), isNull, reason: '$raw');
  }

  group('앱 주소(elum://)', () {
    test('기본 형식', () => accepts('elum://invite?code=A7K3M9'));
  });

  group('웹 주소(https)', () {
    test('쿼리', () => accepts('https://twin-fang.github.io/elum/invite/?code=A7K3M9'));
    test('조각(#) — 서버로 가지 않는 쪽이라 공유 링크가 쓴다', () {
      accepts('https://twin-fang.github.io/elum/invite/#code=A7K3M9');
    });
    test('쿼리와 조각이 둘 다 있으면 쿼리가 이긴다', () {
      accepts('https://twin-fang.github.io/elum/invite/?code=A7K3M9#code=B2C4D6');
    });
  });


  group('코드 모양 변형 — 받는 사람이 손대지 않아도 통해야 한다', () {
    test('다른 파라미터가 앞에 있어도', () => accepts('elum://invite?utm=x&code=A7K3M9'));
    test('같은 파라미터가 두 번이면 첫 번째', () {
      accepts('elum://invite?code=A7K3M9&code=B2C4D6');
    });
  });

  group('초대 링크지만 코드를 못 쓴다 — 화면이 에러 안내를 띄운다', () {
    test('코드가 비었다', () => brokenCode('elum://invite?code='));
    test('길다', () => brokenCode('elum://invite?code=A7K3M9X'));
    test('서버가 만들지 않는 글자(0, O, 1, I, L, U)', () {
      for (final bad in ['A0K3M9', 'AOK3M9', 'A1K3M9', 'AIK3M9', 'ALK3M9', 'AUK3M9']) {
        brokenCode('elum://invite?code=$bad');
      }
    });
  });

  group('초대 링크가 아니다 — 다른 흐름을 건드리지 않는다', () {
    test('다른 호스트·경로', () {
      ignores('elum://other?code=A7K3M9');
      ignores('elum://login?code=A7K3M9');
      ignores('elum://invite/extra?code=A7K3M9');
      ignores('/invite/extra?code=A7K3M9');
      ignores('/guardian');
      ignores('/');
      ignores('');
    });
    test('소셜 로그인 콜백은 건드리지 않는다', () {
      ignores('kakao123456://oauth?code=A7K3M9');
      ignores('elum://oauth?code=A7K3M9');
      ignores('com.googleusercontent.apps.123:/oauth2redirect?code=A7K3M9');
    });
    test('null·엉뚱한 타입·깨진 주소', () {
      ignores(null);
      ignores(42);
      ignores('::::');
      ignores('http://[');
    });
  });

  group('공유 링크 만들기', () {
    test('웹 링크는 코드를 조각(#)에 둔다 — 어떤 서버 로그에도 남지 않는다', () {
      final url = InviteLink.shareUrl('A7K3M9');
      expect(url, 'https://twin-fang.github.io/elum/invite/#code=A7K3M9');
      expect(Uri.parse(url).query, isEmpty);
    });

    test('만든 링크는 우리 해석기로 되돌아온다', () {
      expect(InviteLink.parse(InviteLink.shareUrl('A7K3M9'))?.code, 'A7K3M9');
      expect(InviteLink.parse(InviteLink.appUrl('A7K3M9'))?.code, 'A7K3M9');
    });



    test('쓸 수 없는 코드로는 링크를 만들지 않는다', () {
      expect(() => InviteLink.shareUrl('A0K3M9'), throwsArgumentError);
      expect(() => InviteLink.shareUrl(''), throwsArgumentError);
    });



  });
}
