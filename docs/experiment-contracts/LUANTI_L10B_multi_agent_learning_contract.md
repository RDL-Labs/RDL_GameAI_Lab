# Luanti L10B — 複数個体のM_B学習・行動分離

状態: IMPLEMENTED / ACCEPTANCE COMPLETE。基準 `520f82fb`。
[Evidence](../experiment-evidence/LUANTI_L10B_multi_agent_learning_evidence.md)。
予測・帰納・検査・行動規則は[L10](LUANTI_L10_sensory_learning_action_contract.md)を継承する。

## 問い

同じ継続Luanti WorldでA/Bが、それぞれの感覚記録と直接参加Experienceからrelationを形成し、
自分のM_Bへ明示採用し、その予測で有限Food試行／保留を選べるか。
片方の学習・モデル切替・応答待ちが、他方の経験・予測・身体作用を取り違えないことを検査する。

対象は固定A/Bの2個体。各個体に別の採食区画、Food、Base、壁、遠景の色特徴を配置する。
同じWorld時計を共有し、個体別controllerが独立したHTTP受渡し領域を持つ。
区画はx方向に24離し、毎Episodeの初期化が他方の区画へ触れない。
資源争奪、衝突、協働、他者の経験からの学習はこの実験の問いに含めない。

## 所有と有限予算

- `--luanti-learning-loop --luanti-learning-multi-agent --sensory-observation`で明示有効化。loopback限定。
- Aは`fixture-life-sensory`、Bは`fixture-life-sensory-compact`、revision 1を固定する。
- `MultiAgentSensoryFoodLearning`が個体別のL10 ledgerを保持する。未知agentの動的作成はしない。
- 各個体最大16操作・1再構成、合計最大32操作・2再構成。実機は各12 Episode。
- Experience、形成6件、独立検査2件、Candidate、T1 assessment、active/archive M_Bを個体別に照合する。
- operation / Episode / event / learningのローカルIDは個体内で一意。同じ文字列をA/Bが使っても別受付。
  Experience IDにはrunとagentを含め、relation supportは自分の異なる形成Experience 3件のまま。
- 結果要求には`agent_id`と`decision_id`を必須とする。後者は決定要求・M_B・予測・行動の内容に拘束する。
  他方の結果を同名operationへ入れること、agentだけ付け替えることを拒否する。
- 完全再送は旧結果を返し、容量や支持数を消費しない。内容変更は拒否。
- 各操作のF/F'は決定時の同じM_Bを使用する。他方または自分の後続cutoverで置換しない。
- HTTP入口は既存canonical lockで直列化する。これらはprocess内保証であり、永続台帳・認証ではない。

## World実行と通信

Luaは共通L10 controllerを個体別に起動する。HTTP callbackは結果を受け渡すだけで、身体作用は
globalstep内で実行する。実行前にagent / operation / frame / decision ID、期限、消費済み状態を検査する。
同じ決定を再要求した後でも権限消費は1回。実機では相手の成功HTTP応答を身体受付関数へ再注入し、
身体位置も自分の権限消費数も変えずに拒否することを確認する。

Aのlearn成功応答の受渡しを2秒保留する。Runtime側の再構成・指定されたcutoverは既に終了している。
この間も共通時計は進み、Bが新しいframeを取得し、実身体作用を実行できることを検査する。
これはcallback受渡しの故障注入であり、実ネットワーク遅延や任意障害の保証ではない。

取得は各Episode開始時の近景・遠景・聴覚3frame。予測に使うのは取得済み遠景の色条件のみ。
聴覚は空検出も正常な記録として保持する。OBS-9の周期的な全感覚＋Probeスケジューラーへ
学習を常設接続したものではない。

## 受入比較

各runでA/Bが各12 Episodeを進める。1〜6形成、7〜8未使用検査、9〜10採用後の確認、
11〜12は隠れた通路条件を反転したcanary。World内部の壁条件は選択要求へ渡さない。

| run | A | B | 確認すること |
| --- | --- | --- | --- |
| opposite | 通常対応・採用 | 逆対応・採用 | 同じ色に対し、自分の経験とM_Bから逆の行動を選ぶ |
| a_only | 通常対応・採用 | 通常対応・inactive artifact | Aの切替でBまで学習済みにならない |
| b_only | 通常対応・inactive artifact | 通常対応・採用 | 役割を入れ替えて同じ分離が成立する |

inactive側にも形成・検査・再構成を行う。同条件の初期区画と結果規則を揃え、切替後の行動・観測列の
一致は要求しない。profile差は各個体内で固定し、a_only/b_onlyでactivationを入れ替えて検査する。
未知は有限試行、学習した非取得予測は保留。保留を失敗Experienceへ数えない。
canaryの成功予測→実失敗は差-1として残し、保留により未発見の成功機会とは分ける。

## 停止境界

各個体が自分のM_Bで実行差を作るところまで。固定方法の発明、自律Sleep・review・cutover、
反例からの2回目の再構成、一般Goal/Trajectory、NERV/SOC、共有資源・援助要請・社会学習は未接続。
明示harnessによるcanonical count残差reviewと感覚予測の補助境界を混同しない。
既存単一個体L10と観測v1の契約・既定policyは維持する。
