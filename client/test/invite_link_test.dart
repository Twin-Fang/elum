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
    test('끝 슬래시', () => accepts('elum://invite/?code=A7K3M9'));
    test('호스트 없이 경로로', () => accepts('elum:///invite?code=A7K3M9'));
    test('슬래시 없는 불투명 주소', () => accepts('elum:invite?code=A7K3M9'));
    test('Uri 객체를 넘겨도 같다', () {
      expect(InviteLink.parse(Uri.parse('elum://invite?code=A7K3M9'))?.code, 'A7K3M9');
    });
  });

  group('웹 주소(https)', () {
    test('쿼리', () => accepts('https://twin-fang.github.io/elum/invite/?code=A7K3M9'));
    test('쿼리, 끝 슬래시 없이', () => accepts('https://twin-fang.github.io/elum/invite?code=A7K3M9'));
    test('조각(#) — 서버로 가지 않는 쪽이라 공유 링크가 쓴다', () {
      accepts('https://twin-fang.github.io/elum/invite/#code=A7K3M9');
    });
    test('조각, 끝 슬래시 없이', () => accepts('https://twin-fang.github.io/elum/invite#code=A7K3M9'));
    test('쿼리와 조각이 둘 다 있으면 쿼리가 이긴다', () {
      accepts('https://twin-fang.github.io/elum/invite/?code=A7K3M9#code=B2C4D6');
    });
    test('호스트 대소문자', () => accepts('https://Twin-Fang.GitHub.io/elum/invite/?code=A7K3M9'));
  });

  group('경로만 온 경우 — 플랫폼이 호스트를 떼고 넘긴다', () {
    test('/invite', () => accepts('/invite?code=A7K3M9'));
    test('/elum/invite', () => accepts('/elum/invite?code=A7K3M9'));
    test('/elum/invite/ + 조각', () => accepts('/elum/invite/#code=A7K3M9'));
  });

  group('코드 모양 변형 — 받는 사람이 손대지 않아도 통해야 한다', () {
    test('소문자', () => accepts('elum://invite?code=a7k3m9'));
    test('하이픈', () => accepts('elum://invite?code=A7K-3M9'));
    test('퍼센트 인코딩된 공백', () => accepts('elum://invite?code=A7K%203M9'));
    test('더하기로 인코딩된 공백', () => accepts('elum://invite?code=A7K+3M9'));
    test('앞뒤 공백', () => accepts('elum://invite?code=%20A7K3M9%20'));
    test('파라미터 이름 대문자', () => accepts('elum://invite?CODE=A7K3M9'));
    test('다른 파라미터가 앞에 있어도', () => accepts('elum://invite?utm=x&code=A7K3M9'));
    test('끝에 & 가 남아도', () => accepts('elum://invite?code=A7K3M9&'));
    test('같은 파라미터가 두 번이면 첫 번째', () {
      accepts('elum://invite?code=A7K3M9&code=B2C4D6');
    });
    test('두 번 인코딩된 경우도 한 번 더 풀어 준다', () {
      // 메신저·단축 서비스가 `%` 를 다시 인코딩하는 일이 있다
      accepts('elum://invite?code=A7K%25203M9');
    });
    test('인코딩된 하이픈', () => accepts('elum://invite?code=A7K%2D3M9'));
    test('바깥 문자열 앞뒤 공백', () => accepts('  elum://invite?code=A7K3M9  '));
  });

  group('초대 링크지만 코드를 못 쓴다 — 화면이 에러 안내를 띄운다', () {
    test('코드가 없다', () => brokenCode('elum://invite'));
    test('코드가 비었다', () => brokenCode('elum://invite?code='));
    test('쿼리만 있고 코드 이름이 다르다', () => brokenCode('elum://invite?c=A7K3M9'));
    test('짧다', () => brokenCode('elum://invite?code=A7K3M'));
    test('길다', () => brokenCode('elum://invite?code=A7K3M9X'));
    test('서버가 만들지 않는 글자(0, O, 1, I, L, U)', () {
      for (final bad in ['A0K3M9', 'AOK3M9', 'A1K3M9', 'AIK3M9', 'ALK3M9', 'AUK3M9']) {
        brokenCode('elum://invite?code=$bad');
      }
    });
    test('한글·기호·이모지', () {
      brokenCode('elum://invite?code=%EA%B0%80%EB%82%98%EB%8B%A4%EB%9D%BC%EB%A7%88%EB%B0%94');
      brokenCode('elum://invite?code=A7K3M!');
      brokenCode('elum://invite?code=%F0%9F%98%80%F0%9F%98%80%F0%9F%98%80');
    });
    test('깨진 퍼센트 인코딩에도 던지지 않는다', () {
      brokenCode('elum://invite?code=%');
      brokenCode('elum://invite?code=%E0%A4%A');
      brokenCode('elum://invite?code=%ZZ');
    });
    test('아주 긴 입력도 던지지 않고 코드 없음으로 돌린다', () {
      brokenCode('elum://invite?code=${'A' * 100000}');
      brokenCode('elum://invite?code=${'%25' * 5000}');
    });
    test('세 번 이상 인코딩된 것은 풀지 않는다 — 끝없이 풀지 않는다', () {
      brokenCode('elum://invite?code=A7K%2525203M9');
    });
    test('중복된 파라미터 중 첫 번째가 못 쓸 모양이면 거기서 멈춘다', () {
      brokenCode('elum://invite?code=BAD&code=A7K3M9');
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
    test('다른 사이트가 같은 경로를 써도 초대 링크가 아니다', () {
      ignores('https://example.com/elum/invite/?code=A7K3M9');
      ignores('https://twin-fang.github.io.evil.com/elum/invite/?code=A7K3M9');
    });
    test('암호화되지 않은 http 는 받지 않는다', () {
      ignores('http://twin-fang.github.io/elum/invite/?code=A7K3M9');
    });
    test('방침·도움말 같은 다른 게시 페이지', () {
      ignores('https://twin-fang.github.io/elum/privacy.html');
      ignores('https://twin-fang.github.io/elum/');
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

    test('앱 주소는 쿼리다', () {
      expect(InviteLink.appUrl('A7K3M9'), 'elum://invite?code=A7K3M9');
    });

    test('코드를 대문자로 정리한다 — 서버가 소문자를 주지는 않지만 모양을 한 곳에서 맞춘다', () {
      expect(InviteLink.shareUrl('a7k-3m9'), endsWith('#code=A7K3M9'));
    });

    test('쓸 수 없는 코드로는 링크를 만들지 않는다', () {
      expect(() => InviteLink.shareUrl('A0K3M9'), throwsArgumentError);
      expect(() => InviteLink.shareUrl(''), throwsArgumentError);
    });

    test('공유 문구는 이룸이를 함께 돌본다는 말과 10분 안내, 링크를 담는다', () {
      final text = InviteLink.shareMessage('A7K3M9', validFor: const Duration(minutes: 10));
      expect(text, contains('10분'));
      expect(text, contains(InviteLink.shareUrl('A7K3M9')));
      expect(text, contains('초대 코드'));
      // 용어 규칙 — 연결 암호(이룸이 휴대폰)와 섞지 않고, "아이"라 부르지 않는다
      expect(text, isNot(contains('연결 암호')));
      expect(text, isNot(contains('아이')));
    });

    test('남은 시간이 1분 미만이어도 문구가 어색해지지 않는다', () {
      final text = InviteLink.shareMessage('A7K3M9', validFor: const Duration(seconds: 20));
      expect(text, contains('1분'));
    });

    test('링크가 안 열릴 때를 위해 코드를 3-3으로 한 번 적어 둔다', () {
      final text = InviteLink.shareMessage('A7K3M9', validFor: const Duration(minutes: 10));
      expect(text, contains('A7K 3M9'));
      // 붙은 여섯 글자는 링크 안에만 있다
      expect(RegExp('A7K3M9').allMatches(text).length, 1);
    });
  });
}
