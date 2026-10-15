import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:flutter_test/flutter_test.dart';

/// 공지 응답 읽기 (이슈 #371 · 명세 3-1 · 서버 #370 `AppNoticesResponse`).
///
/// 공지는 부가 기능이다. 응답 하나가 깨졌다고 보호자 홈이 죽으면 안 되고,
/// 항목 하나가 깨졌다고 나머지 공지까지 버리면 안 된다.
void main() {
  const base = 'https://api.test';

  Map<String, Object?> item({
    Object? id = 'n1',
    Object? revision = 1,
    Object? title = '제목',
    Object? body = '본문',
    Object? imageUrl,
    Object? button,
  }) => {
    'id': id,
    'revision': revision,
    'title': title,
    'body': body,
    'imageUrl': imageUrl,
    'button': button,
  };

  NoticeFeed read(Object? json) => NoticeFeed.fromJson(json, baseUrl: base);

  group('서버 계약 — 명세 3-1 그대로 읽는다', () {
    test('정상 응답의 필드를 모두 읽는다', () {
      final feed = read({
        'hideDays': 7,
        'notices': [
          item(
            id: 'a',
            revision: 3,
            title: '베타 기간에는 **하루 3개**까지 만들 수 있어요',
            body: '첫 줄\n둘째 줄',
            imageUrl: '/api/app/notices/a/image?v=9a8b',
            button: {'label': '자세히 보기', 'url': 'https://elum.app/beta'},
          ),
        ],
      });

      expect(feed.hideDays, 7);
      expect(feed.notices, hasLength(1));
      final n = feed.notices.single;
      expect(n.id, 'a');
      expect(n.revision, 3);
      expect(n.title, '베타 기간에는 **하루 3개**까지 만들 수 있어요');
      expect(n.body, '첫 줄\n둘째 줄');
      expect(n.button?.label, '자세히 보기');
      expect(n.button?.url, Uri.parse('https://elum.app/beta'));
    });

  });

  group('N2 응답이 깨져도 그 항목만 버린다', () {
    test('최상위가 객체가 아니어도 예외 없이 빈 목록이다', () {
      for (final broken in <Object?>[null, '문자열', 42, <Object?>[]]) {
        expect(() => read(broken), returnsNormally);
        expect(read(broken).notices, isEmpty, reason: '$broken');
      }
    });

    test('revision 이 정수가 아니면 버린다 — 숨김 판단의 열쇠라서', () {
      final feed = read({
        'notices': [
          item(id: 'a', revision: '1'),
          item(id: 'b', revision: null),
          item(id: 'c', revision: 2.0),
          item(id: 'd', revision: 2),
        ],
      });
      // 2.0 은 JSON 에서 정수로 읽힐 수 있는 값이라 받아 준다
      expect(feed.notices.map((n) => n.id), ['c', 'd']);
    });

  });

  group('N12 https 가 아닌 링크는 버튼을 숨긴다', () {
    test('https 가 아니면 버튼만 빼고 공지는 남긴다', () {
      final feed = read({
        'notices': [
          item(id: 'http', button: {'label': '보기', 'url': 'http://x.test'}),
          item(id: 'js', button: {'label': '보기', 'url': 'javascript:alert(1)'}),
          item(id: 'intent', button: {'label': '보기', 'url': 'intent://x'}),
          item(id: 'nohost', button: {'label': '보기', 'url': 'https://'}),
          item(id: 'ok', button: {'label': '보기', 'url': 'https://x.test'}),
        ],
      });
      expect(feed.notices, hasLength(5));
      expect(
        {for (final n in feed.notices) n.id: n.button != null},
        {
          'http': false,
          'js': false,
          'intent': false,
          'nohost': false,
          'ok': true,
        },
      );
    });

  });


}
