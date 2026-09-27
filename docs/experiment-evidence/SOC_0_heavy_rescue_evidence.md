# SOC-0 単独失敗から共同搬送成立へのEvidence

状態: **PASS / SOC0-01〜10完了** / 2026-09-27。
実装開始点: `ac8853a`。[契約](../experiment-contracts/SOC_0_heavy_rescue_contract.md)。

## 実Worldで確認した一周

Godot 4.7.2 headlessの既存mock world + localhost既存RescueTrajectoryPolicyを実行した。
A/BにCを加えた専用providerのみを使用し、Bのincapacitationは既存のflee失敗3回で作った。
AはRuntimeが選んだapproachを3回実行して接近した。

```text
approach ×3
→ rescue（Aのみ、実失敗）
→ harnessがCの有効参加を設定
→ rescue（A+C、成立）
→ approach ×6（既存搬送移動）
→ deliver（既存safe-place resolver）
→ idle / COMPLETE
→ stabilizing → mobilizing → recovering → recovered
```

同じBについて、SOLO直前/直後の位置が一致し、carried_agent_idは空。
Cは最初からB付近に存在するが、SOLO参加集合には入っていない。
JOINTではA/C能力合計2がB荷重2を満たしてattachし、Bが既存搬送経路でPlazaへ到達した。
Recoveryは既存Worldの4tickを実行し、最後はinjuryなし・行動可能。専用Recoveryは作っていない。

実WorldはGodot mock worldの有限な運動・身体状態であり、Luantiでの共同搬送でも剛体物理でもない。
Cの参加設定はharnessが行い、Cの運動はWorld側でAの移動差分へ同期する。
Aが失敗原因を理解してCへ頼んだ、Cが自律判断で助けた、という検証ではない。

## 能力合成と有限性の対照

| 対照 | 結果 |
| --- | --- |
| A能力2・B荷重2、A単独 | attach成立 |
| A/C各1・B荷重3 | 2個体でもattach不成立 |
| Aを重複指定 | 二重加算せず不成立 |
| Cが範囲外 | 不成立 |
| Cが行動不能 | 不成立 |
| attach後にC参加解除 | Bの搬送進行なし |

対照fixtureの身体・位置条件は試験側が明示設定した。主runのRuntime決定列とは分ける。
失敗条件で新規decisionを繰り返してもcarry試行は2回で停止し、Bの位置とAのEnergyは不変。
成功済み対象の再attachは防止。同じ決定の再送でも試行・Experienceは増えない。
これらはprocess内の有限fixture保証であり、任意ネットワーク障害やrestartは対象外。

## Experience・漏えい・学習境界

Godot記録を変更せず[再生JSON](../../tests/fixtures/soc0_godot_replay.json)へ保存した。
`world_checks`は実験者の位置検査用で、NPCへ渡すExperienceやRuntime packetとは分離する。

`RescueExperienceStore`が次の3eventを別recordとして受理した。

| event | participants | result |
| --- | --- | --- |
| soc0-real-world:event:0 | A | carry_not_established |
| soc0-real-world:event:1 | A, C | carry_established |
| soc0-real-world:event:2 | A, C | delivered |

各記録に観測前後の参照、target B、body/world consequenceがある。
荷重・能力合計・必要人数・correct helperは、全実Runtime packet、最終A/B/C観測、全Experienceに含まれないことを検査した。
HTTPは既存の行動/approach結果経路。SOC-0 Experienceの受理はGodot JSON出力をPythonで明示取込したもので、新しいlive Experience endpointはない。
再取込で件数不変、変更event/容量超過/情報漏えいfield/不整合結果は拒否。

Rescue policyはCOMPLETE後にcommitを解放し、canonical T1-A材料は0件。
社会的reward、friendship/trust/role/usefulness、NERV/T1への新hookは存在しない。
Outcome差を今後の学習へ渡せる記録を作った段階である。

## 検証結果

SOC-0専用: **4テストPASS**（Godot有効）。

```text
$env:GODOT_BIN='D:\Godot\Godot_v4.7.2-stable_win64_console.exe'
python -m unittest discover -s tests -p test_social_rescue.py -v
Ran 4 tests / OK
```

既存Godot回帰: single-carrier delivery、Multi-Agent Rescue、段階Recovery、通常CLI Rescue起動の**4件PASS**。
既存Luanti複数個体生活: **MULTI LIFE PASS / 2 pickups・2 deposits・2 results**。
Observation v1: **実Luanti 8run全件PASS / 各108frame・合計864frame**。
normal/swap/delayed/faultsはreobserved、preempt/same_slotはaborted、removedはnot_reobserved、partialはacquisition_incomplete。
全runでA/B生活が完了。専用SOC-0がこのLuanti runへ入っているという意味ではない。

全体回帰（GODOT_BIN未設定）:

```text
python -m unittest discover -s tests -v
Ran 487 tests
OK (skipped=47)
487件実行 = 440 PASS + 47 intentional skip
```

47skipには外部Godot用の新SOC-0試験1件を含む。それは上記専用実行で別途PASS。
既存46外部試験を全件再実行したとは主張しない。NERV-1〜4Cは全体Python回帰で検証し、NERV-4Dは設計のみのまま維持する。

| 受入 | 確認内容 |
| --- | --- |
| SOC0-01/02 | 実rescue失敗、B位置不変、有限試行・Energy不変 |
| SOC0-03 | Runtime packet/観測/Experienceのhidden情報非漏えい、store厳密field |
| SOC0-04/05 | 同じBのJOINT成立、能力2単独成功/2個体不足/無効参加対照 |
| SOC0-06 | 既存carry→delivery→4段階Recovery実行 |
| SOC0-07 | 別event/record、観測出典、取込再送非増殖 |
| SOC0-08 | 社会学習・自動価値付与なし、T1-A材料0 |
| SOC0-09 | 既存Godot4試験、Luanti生活/OBS9全8run、全体回帰 |
| SOC0-10 | Experience取得まで。自律援助要請・NERV/T1接続は未実装 |

**SOC-0はこの範囲で完了し停止する。**
