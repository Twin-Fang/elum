# ELUM（イルム）

[English](README.md) · [한국어](README.ko.md) · [简体中文](README.zh.md) · **日本語**

<p align="center">
  <img src="docs/images/readme/hero.jpg" alt="ELUM：今日という一日を、一歩ずつ、いっしょに" width="720">
</p>

<p align="center">
  <b>今日という一日を、一歩ずつ、いっしょに。</b><br>
  発達障害のある方が日々の暮らしを自分で進め、自立していくのを支えるモバイルサービスです。
</p>

<p align="center">
  <a href="https://apps.apple.com/kr/app/id6792970508"><img src="https://img.shields.io/badge/App_Store-Download-black?logo=apple&logoColor=white" alt="App Store からダウンロード"></a>
  <a href="https://play.google.com/store/apps/details?id=kr.twinfang.elum"><img src="https://img.shields.io/badge/Google_Play-Get_it-3DDC84?logo=googleplay&logoColor=white" alt="Google Play で手に入れよう"></a>
</p>

---

## ELUM とは？

保護者がふだんの言葉で今日の予定を書くと、ELUM の AI がイラスト付きの短い**行動カード**に分けてくれます。利用する方はカードを一枚ずつ見ながら行動し、チェックを入れ、ほめ言葉とスターをもらいます。

利用する方には、わかりやすい一日の流れと「できた」という前向きな体験を。保護者には、同じ準備を何度も繰り返す負担の軽減を届けます。

<p align="center">
  <img src="docs/images/readme/flow.gif" alt="予定の入力からスターをためるまで" width="360">
</p>

## なぜ作ったのか

- **保護者**は同じ指示を何度も繰り返し、視覚スケジュールや絵カードを手作りするのに多くの時間を使っています。
- **発達障害のある方**は、抽象的な指示や複数の内容が混ざった指示を理解しにくく、日々の行動を自分でつなげて実行するのが難しいことがあります。

ELUM は、保護者がそのつど付き添わなくても、本人が自分で一日の予定を進められるようにする自立支援サービスを目指しています。

## 使い方

<table>
  <tr>
    <td align="center" width="50%">
      <img src="docs/images/readme/screen-create.png" alt="今日の予定を伝える" width="340"><br>
      <b>1. 今日の予定を伝える</b><br>
      保護者がやることを入力します。情報が足りないときは、ELUM が先に質問します。
    </td>
    <td align="center" width="50%">
      <img src="docs/images/readme/screen-cards.png" alt="行動カードができる" width="340"><br>
      <b>2. 行動カードができる</b><br>
      予定が、絵付きの小さなステップに分かれます。順番と内容は保護者が直せて、確認してからはじめて本人に表示されます。
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="docs/images/readme/screen-follow.png" alt="カードを見て行動し、チェックする" width="340"><br>
      <b>3. 見ながら行動してチェック</b><br>
      絵を見て行動し、自分でチェックします。小さな成功が積み重なります。
    </td>
    <td align="center">
      <img src="docs/images/readme/screen-stars.png" alt="ほめ言葉とスター" width="340"><br>
      <b>4. ほめ言葉とスター</b><br>
      行動を終えると、ほめ言葉とスターで「できた」が目に見えます。
    </td>
  </tr>
</table>

## ABA の考え方を参考にした設計

ELUM の 3 ステップの仕組みは、ABA（応用行動分析）の考え方を参考にしています。

| ステップ | ELUM では |
| --- | --- |
| **1. 指示** | カードごとに、ひとつの行動を短くはっきり伝えます。 |
| **2. 行動** | 本人が絵を見ながら、一歩ずつ行動します。 |
| **3. 強化** | 保護者が決めたごほうびを、行動の前・最中・後に思い出させます。 |

アプリ内のスターは、できたことを見せるための演出です。おやつ、遊び、散歩などの実際のごほうびは、保護者が決めます。

## 主な機能

- 一日の予定を書くだけで AI が作る**イラスト付き行動カード**
- カードを読み上げる**音声ガイド**
- すべてのカードに登場する**親しみやすいキャラクター**
- 本人に見せる前に、**保護者がすべてのカードを確認して修正**
- **保護者が決めるごほうび**と、行動を終えるたびにもらえるスター
- ひとつのアプリに**保護者用画面と本人用画面**があり、パスコードで切り替え

## 対応言語

現在は韓国語に対応しています。英語、中国語、日本語を準備中です。

## ヘルプと規約

[ヘルプ](https://twin-fang.github.io/elum/) · [プライバシーポリシー](https://twin-fang.github.io/elum/privacy.html) · [アカウントとデータの削除](https://twin-fang.github.io/elum/delete.html)

## チーム

ELUM は、ハッカソン「장애 플러스 기술」（障害プラス技術）にチーム LUMLUM として参加したことから始まりました。

| メンバー | 役割 |
| --- | --- |
| 서새찬 | PM · Frontend |
| 백지훈 | Backend · AI |
| 이예람 | UX/UI |

## 著作権

© 2026 チーム LUMLUM. All rights reserved. 詳しくは [LICENSE](./LICENSE) をご覧ください。
