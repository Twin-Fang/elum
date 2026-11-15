// 미리보기 데모 데이터: 언어별 이룸이 이름·일과 3개 (스토어 스크린샷용, #1419)
// 언어 코드 ko·en·ja·zh·es > 같은 그림(pictogramId), 같은 진행률, 문구만 언어별
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';

/// 언어 1개 데모: 이룸이 이름 + 오늘 일과
class PreviewDemoData {
  const PreviewDemoData({required this.nickname, required this.routines});

  final String nickname;
  final List<Routine> routines;
}

/// 카드 문구 1장: 제목, 설명
typedef _CardText = (String title, String description);

/// 언어별 문구 묶음: 일과 제목 3개, 보상 1개, 카드 9장 (순서 = 아래 그림 순서)
class _DemoTexts {
  const _DemoTexts({
    required this.nickname,
    required this.morningTitle,
    required this.handWashTitle,
    required this.bedtimeTitle,
    required this.rewardText,
    required this.cards,
  });

  final String nickname;
  final String morningTitle;
  final String handWashTitle;
  final String bedtimeTitle;
  final String rewardText;
  final List<_CardText> cards;
}

// 카드 그림 9장 (언어와 무관): 아침 4 · 손 씻기 3 · 잠자기 전 2
const _pictogramIds = [
  'wash_face_,_to',
  'put_on_coat_,_to',
  'school_bag',
  'shoe_-_mans',
  'wash_hands_,_to',
  'soap',
  'towel',
  'brush_teeth_,_to',
  'turn_off_,_to',
];

const _textsByLanguage = <String, _DemoTexts>{
  'ko': _DemoTexts(
    nickname: '하늘이',
    morningTitle: '아침에 학교 갈 준비',
    handWashTitle: '저녁 먹기 전 손 씻기',
    bedtimeTitle: '잠자기 전 정리',
    rewardText: '젤리 먹기',
    cards: [
      ('세수해요', '물로 얼굴을 깨끗이 씻어요'),
      ('옷을 입어요', '학교에 갈 옷을 차례대로 입어요'),
      ('가방을 챙겨요', '책과 필통을 가방에 넣어요'),
      ('신발을 신어요', '현관에서 신발을 신어요'),
      ('손을 적셔요', '물을 틀고 손을 적셔요'),
      ('비누칠을 해요', '손바닥과 손등을 비벼요'),
      ('헹구고 닦아요', '물로 헹구고 수건으로 닦아요'),
      ('이를 닦아요', '칫솔로 이를 구석구석 닦아요'),
      ('불을 꺼요', '잘 자요, 불을 꺼요'),
    ],
  ),
  'en': _DemoTexts(
    nickname: 'Sky',
    morningTitle: 'Getting ready for school',
    handWashTitle: 'Washing hands before dinner',
    bedtimeTitle: 'Tidying up before bed',
    rewardText: 'Eat a jelly',
    cards: [
      ('Wash your face', 'Wash your face clean with water'),
      ('Get dressed', 'Put on your school clothes one by one'),
      ('Pack your bag', 'Put your books and pencil case in your bag'),
      ('Put on your shoes', 'Put on your shoes at the door'),
      ('Wet your hands', 'Turn on the water and wet your hands'),
      ('Use soap', 'Rub your palms and the backs of your hands'),
      ('Rinse and dry', 'Rinse with water and dry with a towel'),
      ('Brush your teeth', 'Brush every tooth with your toothbrush'),
      ('Turn off the light', 'Good night, turn off the light'),
    ],
  ),
  'ja': _DemoTexts(
    nickname: 'そら',
    morningTitle: '朝、学校に行く準備',
    handWashTitle: '夕ごはんの前の手洗い',
    bedtimeTitle: '寝る前の片づけ',
    rewardText: 'グミを食べる',
    cards: [
      ('顔を洗います', '水で顔をきれいに洗います'),
      ('服を着ます', '学校に着ていく服を順番に着ます'),
      ('かばんを用意します', '本と筆箱をかばんに入れます'),
      ('くつをはきます', '玄関でくつをはきます'),
      ('手をぬらします', '水を出して手をぬらします'),
      ('せっけんをつけます', '手のひらと手の甲をこすります'),
      ('すすいでふきます', '水ですすいでタオルでふきます'),
      ('歯をみがきます', '歯ブラシですみずみまでみがきます'),
      ('電気を消します', 'おやすみなさい、電気を消します'),
    ],
  ),
  'zh': _DemoTexts(
    nickname: '小天',
    morningTitle: '早上上学准备',
    handWashTitle: '晚饭前洗手',
    bedtimeTitle: '睡前整理',
    rewardText: '吃软糖',
    cards: [
      ('洗脸', '用水把脸洗干净'),
      ('穿衣服', '按顺序穿上上学的衣服'),
      ('收拾书包', '把书和笔袋放进书包'),
      ('穿鞋', '在门口穿上鞋'),
      ('打湿双手', '打开水龙头把手打湿'),
      ('抹肥皂', '搓搓手心和手背'),
      ('冲洗擦干', '用水冲洗，再用毛巾擦干'),
      ('刷牙', '用牙刷把每颗牙都刷干净'),
      ('关灯', '晚安，把灯关掉'),
    ],
  ),
  'es': _DemoTexts(
    nickname: 'Cielo',
    morningTitle: 'Prepararse para el colegio',
    handWashTitle: 'Lavarse las manos antes de cenar',
    bedtimeTitle: 'Ordenar antes de dormir',
    rewardText: 'Comer una gominola',
    cards: [
      ('Lávate la cara', 'Lávate bien la cara con agua'),
      ('Vístete', 'Ponte la ropa del colegio paso a paso'),
      ('Prepara la mochila', 'Mete los libros y el estuche en la mochila'),
      ('Ponte los zapatos', 'Ponte los zapatos en la entrada'),
      ('Mójate las manos', 'Abre el grifo y mójate las manos'),
      ('Usa jabón', 'Frota las palmas y el dorso de las manos'),
      ('Enjuaga y seca', 'Enjuágate con agua y sécate con la toalla'),
      ('Lávate los dientes', 'Cepilla bien cada diente'),
      ('Apaga la luz', 'Buenas noches, apaga la luz'),
    ],
  ),
};

/// 언어 코드 > 데모 데이터 (모르는 언어는 영어)
PreviewDemoData toPreviewDemoData(String languageCode) {
  final texts = _textsByLanguage[languageCode] ?? _textsByLanguage['en']!;
  final language = _textsByLanguage.containsKey(languageCode)
      ? languageCode
      : 'en';
  ActionCard cardAt(
    String routineId,
    int cardIndex,
    int stepOrder, {
    bool isCompleted = false,
  }) => ActionCard(
    id: '${routineId}c$stepOrder',
    stepOrder: stepOrder,
    title: texts.cards[cardIndex].$1,
    description: texts.cards[cardIndex].$2,
    pictogramId: _pictogramIds[cardIndex],
    completed: isCompleted,
  );

  return PreviewDemoData(
    nickname: texts.nickname,
    routines: [
      Routine(
        id: 'r1',
        title: texts.morningTitle,
        status: 'CONFIRMED',
        rewardText: texts.rewardText,
        rewardPresetKey: 'SNACK',
        progressPercent: 25,
        completedStepCount: 1,
        totalStepCount: 4,
        language: language,
        steps: [
          for (var index = 0; index < 4; index++)
            cardAt('r1', index, index + 1, isCompleted: index == 0),
        ],
      ),
      Routine(
        id: 'r2',
        title: texts.handWashTitle,
        status: 'CONFIRMED',
        progressPercent: 0,
        totalStepCount: 3,
        language: language,
        steps: [
          for (var index = 4; index < 7; index++)
            cardAt('r2', index, index - 3),
        ],
      ),
      Routine(
        id: 'r3',
        title: texts.bedtimeTitle,
        status: 'COMPLETED',
        progressPercent: 100,
        completedStepCount: 2,
        totalStepCount: 2,
        language: language,
        steps: [
          for (var index = 7; index < 9; index++)
            cardAt('r3', index, index - 6, isCompleted: true),
        ],
      ),
    ],
  );
}
