# Lightweight Sleep学習接続 v1

状態: FINITE IMPLEMENTED。2026-10-03。基準 dc4e76c。

`timed_harvest --sleep-learning` の明示opt-in。無指定は従来の日中採用。
身体の夜間waitと学習処理を分け、実際の夜間wait結果と次観測の身体参照が対応し、
連続1秒の休止を確認した時だけ一晩一回処理する。1操作の加算は最大250ms。
危険対応・身体参照不足・未実行では連続時間をリセット。日を越した未完了分は
interrupted。野宿を許すが、安全な睡眠場所を確認したという意味ではない。
夜間に一度も入れない場合はcycle自体を生成しない。再送は既存observe受付で除外。

## 二つの処理

1. **異種経験の関係検査**。現在の採取目標との関連性を事前条件にしない。
   本人の直近64観測から、実結果のあるaction/outcome/phaseごとの最新代表を
   最大6件取得。move/turn/pickup/wait、警戒中の操作も排除しない。
   夜間開始時に凍結し、既存SleepExperienceWindowStoreと
   compare_relation_profilesで最大15組を比較する。
   行為・結果・観測対象参照・観測されたFood/危険の有無を投影。
   両感覚のcoverageがcompleteでない場合、contextは欠測として扱う。
   共通・相違・欠測を保存するだけで、因果的な拘束、一般則、M_B採用とはしない。
   共通するactorだけでも共通項は出るが、有用な法則の発見とは数えない。
2. **既存採取relationの夜間採用**。日中は採取記録を集めるだけにし、従来の
   build_admissionによる3件形成＋独立2件検査＋既存T1再構成/切替を夜に行う。
   最初の最大6件を凍結、従来同様先頭5件で検査。反例を成功例で置き換えない。
   経験不足、DEFER、REJECT、既存モデルありを分ける。既存モデルの置換は行わない。
   count差の既存T1証拠はcheckpointまでの本人観測を使用する。

二つの窓は別目的。比較で採取以外の関係が似たことを理由に、採取の支持数を増やさない。
既にモデルがある夜も異種比較は続ける。sleep状態はlearningとともにobserve成功時に公開する。

## 既存資産との関係

- 再利用: Sleep経験窓、reported relation構築、構造比較、既存採取T1採用経路。
- 旧SleepConsolidationCoordinatorのsafe place / sleep action / approach専用compilerを
  偽装して通さない。旧公開入口は変更しない。
- 異種比較はGameAI-local診断。NERV、汎用Deep Candidate、異種relationのT1採用、
  自由連想、全履歴検索、睡眠中の神経parameter更新は未接続。
- 昼間の経路強化・局所E/H更新まで睡眠へ移したわけではない。
- 一見無関係な経験も検査対象にできる入口であり、任意の経験から意味や因果を
  発見する機構が完成したわけではない。64観測窓より古い経験の広域再活性化は次工程。

[実験結果](../experiment-evidence/LW_sleep_learning.md)
