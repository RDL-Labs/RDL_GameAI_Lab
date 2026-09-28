# SOC-5 実失敗後の有限候補展開 Evidence

2026-09-28。対象: `runtime/failure_response_candidates.py`。  
契約: [SOC-5](../experiment-contracts/SOC_5_failure_response_candidate_expansion_contract.md)。

## 実装した範囲

実`RescueExperience`のsolo `carry_not_established`と、その直後の有限Contextから、固定6候補をshadow-onlyで展開する。

```text
retry
reposition
known_tool
seek_agent
wait
abandon
```

出力には選択・score・rank・action権限を持たせない。

## 専用検査

`tests/test_failure_response_candidates.py`で以下を確認する。

- 実solo failureからのみ候補展開。
- retry / repositionの有限budget・readiness。
- 既知道具参照があるときだけ`known_tool=available`。
- 観測他個体参照があるときだけ`seek_agent=available`。
- partial coverageで参照なしを`unresolved`として保持。
- hidden `required_carriers / carry_load / combined_capacity / correct_helper_id / requires_helper`を拒否。
- trust / friend / usefulness / CALL / HELP / POINT / DialogueTurnを生成しない。
- 入力非変更、返却値非alias、参照配列順によるID差なし。

## 停止境界

このEvidenceは、

```text
失敗
→ candidate expansion
```

までの検査である。

以下は未実装。

```text
candidate selection
seek_agent → helper choice
CALL / HELP / POINT
listener interpretation
共同再試行
relation Candidate
known-tool execution
novel substitution / composition
```

したがって「NPCが助けを求めるようになった」「工夫を自律選択した」「道具を発明した」という主張はしない。

## 実行結果

専用8テストをローカル再生し、**8/8 PASS**。

```text
python -m unittest tests/test_failure_response_candidates.py -v
Ran 8 tests
OK
```

この結果はSOC-5専用純粋関数の検査であり、全体回帰・Godot実World・Luanti・Communication実行の検証ではない。
