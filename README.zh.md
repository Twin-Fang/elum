# ELUM（이룸）

[English](README.md) · [한국어](README.ko.md) · **简体中文** · [日本語](README.ja.md)

<p align="center">
  <img src="docs/images/readme/hero.jpg" alt="ELUM：今天一天，一步一步，一起走" width="720">
</p>

<p align="center">
  <b>今天一天，一步一步，一起走。</b><br>
  帮助发育障碍者独立完成日常事务、走向自立的手机应用。
</p>

<p align="center">
  <a href="https://apps.apple.com/kr/app/id6792970508"><img src="https://img.shields.io/badge/App_Store-Download-black?logo=apple&logoColor=white" alt="在 App Store 下载"></a>
  <a href="https://play.google.com/store/apps/details?id=kr.twinfang.elum"><img src="https://img.shields.io/badge/Google_Play-Get_it-3DDC84?logo=googleplay&logoColor=white" alt="在 Google Play 获取"></a>
</p>

---

## ELUM 是什么？

监护人用日常的说法写下今天要做的事，ELUM 的 AI 会把它拆成带插图的简短**行动卡片**。使用者一张一张照着做、逐一打勾，并在过程中获得表扬和星星。

对使用者来说，是易于理解的日程和“我做到了”的积极体验；对监护人来说，则减轻了反复准备同样内容的负担。

<p align="center">
  <img src="docs/images/readme/flow.gif" alt="从输入日程到收集星星" width="360">
</p>

## 为什么要做 ELUM

- **监护人**需要无休止地重复同样的指令，还要花大量时间亲手制作视觉日程表和图片卡片。
- **发育障碍者**往往难以理解抽象或包含多个步骤的指令，也很难自己把日常行动串联起来完成。

ELUM 的目标是成为一项自立辅助服务：即使监护人不必每次都在旁边介入，使用者也能自己完成日常事务。

## 使用方法

<table>
  <tr>
    <td align="center" width="50%">
      <img src="docs/images/readme/screen-create.png" alt="告诉 ELUM 今天要做什么" width="340"><br>
      <b>1. 说说今天要做的事</b><br>
      监护人输入需要完成的事。信息不够时，ELUM 会先提问。
    </td>
    <td align="center" width="50%">
      <img src="docs/images/readme/screen-cards.png" alt="生成行动卡片" width="340"><br>
      <b>2. 生成行动卡片</b><br>
      日程会被拆成带图片的小步骤。顺序和内容可由监护人修改，经监护人确认后才会展示给使用者。
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="docs/images/readme/screen-follow.png" alt="照着卡片做并打勾" width="340"><br>
      <b>3. 照着做并打勾</b><br>
      看着图片行动，亲手打勾。小小的成功不断积累。
    </td>
    <td align="center">
      <img src="docs/images/readme/screen-stars.png" alt="表扬与星星" width="340"><br>
      <b>4. 获得表扬和星星</b><br>
      完成行动后会得到表扬和星星，让完成的成果看得见。
    </td>
  </tr>
</table>

## 参考 ABA 原理的设计

ELUM 的三步结构参考了 ABA（应用行为分析）的原理。

| 步骤 | 在 ELUM 中 |
| --- | --- |
| **1. 指示** | 每张卡片用简短明确的话说明一个行动。 |
| **2. 行动** | 使用者看着图片，一步一步照着做。 |
| **3. 强化** | 在行动之前、之中、之后，提醒使用者监护人设定的奖励。 |

应用内的星星用来展示完成的进度。零食、玩耍、散步等现实中的奖励由监护人决定。

## 主要功能

- 根据对一天的描述，由 AI 生成**带插图的行动卡片**
- 朗读卡片内容的**语音引导**
- 出现在每张卡片上的**亲切角色**
- **监护人可确认并修改**每张卡片，再展示给使用者
- **由监护人设定的奖励**，每完成一个行动就获得星星
- 一个应用内含**监护人界面和使用者界面**，通过密码切换

## 支持语言

目前支持韩语，英语、中文和日语正在准备中。

## 帮助与条款

[帮助](https://twin-fang.github.io/elum/) · [隐私政策](https://twin-fang.github.io/elum/privacy.html) · [删除账号和数据](https://twin-fang.github.io/elum/delete.html)

## 团队

ELUM 以 LUMLUM 团队的身份，从 2026 年黑客松「장애 플러스 기술」（残障加技术）开始。

| 成员 | 职责 |
| --- | --- |
| 서새찬 | PM · Frontend |
| 백지훈 | Backend · AI |
| 이예람 | UX/UI |

## 版权

© 2026 LUMLUM 团队。保留所有权利。详见 [LICENSE](./LICENSE)。
