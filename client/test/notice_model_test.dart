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

    test('이미지 주소가 서버 기준 경로면 서버 주소에 붙인다', () {
      // #370 은 `/api/app/notices/{id}/image?v=…` 처럼 경로만 보낸다.
      // 그대로 Image.network 에 넘기면 호스트가 없어 그림이 안 뜬다.
      final n = read({
        'notices': [item(imageUrl: '/api/app/notices/a/image?v=1')],
      }).notices.single;
      expect(n.imageUrl, 'https://api.test/api/app/notices/a/image?v=1');
    });

    test('이미지 주소가 https 절대 주소면 그대로 쓴다', () {
      final n = read({
        'notices': [item(imageUrl: 'https://cdn.test/a.png')],
      }).notices.single;
      expect(n.imageUrl, 'https://cdn.test/a.png');
    });

    test('서버 주소 끝의 / 와 경로 앞의 / 가 겹치지 않는다', () {
      final feed = NoticeFeed.fromJson({
        'notices': [item(imageUrl: '/img')],
      }, baseUrl: 'https://api.test/');
      expect(feed.notices.single.imageUrl, 'https://api.test/img');
    });
  });

  group('N2 응답이 깨져도 그 항목만 버린다', () {
    test('최상위가 객체가 아니어도 예외 없이 빈 목록이다', () {
      for (final broken in <Object?>[null, '문자열', 42, <Object?>[]]) {
        expect(() => read(broken), returnsNormally);
        expect(read(broken).notices, isEmpty, reason: '$broken');
      }
    });

    test('notices 가 목록이 아니면 빈 목록이다', () {
      expect(read({'notices': '없음'}).notices, isEmpty);
      expect(read({'hideDays': 7}).notices, isEmpty);
    });

    test('id 가 없거나 비었으면 그 항목만 버린다', () {
      final feed = read({
        'notices': [
          item(id: null),
          item(id: '  '),
          item(id: 7),
          item(id: 'ok'),
        ],
      });
      expect(feed.notices.map((n) => n.id), ['ok']);
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

    test('제목·본문이 없거나 공백뿐이면 버린다', () {
      final feed = read({
        'notices': [
          item(id: 'a', title: null),
          item(id: 'b', title: '   '),
          // 표기만 있으면 화면에 보이는 글자가 없다
          item(id: 'c', title: '****'),
          item(id: 'd', body: null),
          item(id: 'e', body: '  \n '),
          item(id: 'f'),
        ],
      });
      expect(feed.notices.map((n) => n.id), ['f']);
    });

    test('항목이 객체가 아니면 버리고 나머지를 쓴다', () {
      final feed = read({
        'notices': ['문자열', 3, null, item(id: 'ok')],
      });
      expect(feed.notices.map((n) => n.id), ['ok']);
    });

    test('이미지 주소가 문자열이 아니거나 이상하면 이미지만 뺀다 — 항목은 남긴다', () {
      final feed = read({
        'notices': [
          item(id: 'a', imageUrl: 42),
          item(id: 'b', imageUrl: 'image.png'),
          item(id: 'c', imageUrl: ''),
        ],
      });
      expect(feed.notices.map((n) => n.id), ['a', 'b', 'c']);
      expect(feed.notices.map((n) => n.imageUrl), everyElement(isNull));
    });

    test('같은 id 가 두 번 오면 앞의 것만 쓴다', () {
      final feed = read({
        'notices': [item(id: 'a', title: '첫째'), item(id: 'a', title: '둘째')],
      });
      expect(feed.notices.single.title, '첫째');
    });

    test('다섯 개가 넘게 와도 앞의 다섯 개만 쓴다', () {
      final feed = read({
        'notices': [for (var i = 0; i < 7; i++) item(id: 'n$i')],
      });
      expect(feed.notices.map((n) => n.id), ['n0', 'n1', 'n2', 'n3', 'n4']);
    });

    test('hideDays 가 없거나 이상하면 7, 범위 밖이면 1~30 으로 자른다', () {
      expect(read({'notices': []}).hideDays, 7);
      expect(read({'hideDays': '7'}).hideDays, 7);
      expect(read({'hideDays': 0}).hideDays, 1);
      expect(read({'hideDays': 99}).hideDays, 30);
      expect(read({'hideDays': 3}).hideDays, 3);
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

    test('문구나 링크 한쪽만 있으면 버튼을 숨긴다', () {
      final feed = read({
        'notices': [
          item(id: 'a', button: {'label': '', 'url': 'https://x.test'}),
          item(id: 'b', button: {'label': '보기'}),
          item(id: 'c', button: '보기'),
        ],
      });
      expect(feed.notices.map((n) => n.button), everyElement(isNull));
    });
  });

  group('N25 제목 강조 — **…** 만, 짝이 안 맞으면 표기를 지운다', () {
    test('**…** 안쪽만 강조한다', () {
      final parts = parseNoticeTitle('베타 기간에는 **하루 3개**까지 만들 수 있어요');
      expect(parts, [
        const NoticeTitlePart('베타 기간에는 ', emphasized: false),
        const NoticeTitlePart('하루 3개', emphasized: true),
        const NoticeTitlePart('까지 만들 수 있어요', emphasized: false),
      ]);
    });

    test('강조가 여러 곳이어도 홀수 번째 조각이 강조다 — 서버 NoticeEmphasis 와 같은 규칙', () {
      final parts = parseNoticeTitle('**A**와 **B**');
      expect(parts, [
        const NoticeTitlePart('A', emphasized: true),
        const NoticeTitlePart('와 ', emphasized: false),
        const NoticeTitlePart('B', emphasized: true),
      ]);
    });

    test('짝이 안 맞으면 강조 없이 ** 만 지운다', () {
      expect(parseNoticeTitle('하루 **3개까지'), [
        const NoticeTitlePart('하루 3개까지', emphasized: false),
      ]);
      expect(parseNoticeTitle('**A** 그리고 **B'), [
        const NoticeTitlePart('A 그리고 B', emphasized: false),
      ]);
    });

    test('표기가 없으면 한 조각이다', () {
      expect(parseNoticeTitle('공지'), [
        const NoticeTitlePart('공지', emphasized: false),
      ]);
    });

    test('빈 강조(****)는 조각을 만들지 않는다', () {
      expect(parseNoticeTitle('앞****뒤'), [
        const NoticeTitlePart('앞', emphasized: false),
        const NoticeTitlePart('뒤', emphasized: false),
      ]);
    });
  });

  group('보지 않기 문구', () {
    test('7일이면 일주일간, 아니면 N일간', () {
      expect(noticeHideLabel(7), '일주일간 보지 않기');
      expect(noticeHideLabel(3), '3일간 보지 않기');
      expect(noticeHideLabel(30), '30일간 보지 않기');
    });
  });
}
