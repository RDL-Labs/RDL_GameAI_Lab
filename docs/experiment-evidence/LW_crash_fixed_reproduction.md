# LW Windowsアクセス違反 — 固定条件での再現調査

2026-10-07。基準 `9ce3f5f444ed33bebad09bcb5e90785e83f56693`。
**3回とも完了。今回の固定条件ではアクセス違反を再現できず、原因未特定・修復未確認。**

## 固定した条件

- 同じPython実体: bundled Python 3.12.14 / MSC v.1944 / AMD64。
- Windows 11 build 26300。同じホスト、同じruntime/integrationsソースSHA-256。
- seed 20261005、run_id lw-scaled-base、social_base、A/B/C、human_scale_v1。
- 1回1,800 World秒（人間換算2時間30分）。毎回新規プロセス・新規World・別出力先。
- `PYTHONHASHSEED=0`を明示。元の失敗時は未固定なので、この差を隠さない。
- 前回と同じoptions生成・run・auditを呼び、行動係数やモデルを変更しない。
- faulthandler、stdout/stderr分離、ネイティブ終了コード、毎秒のプロセスメモリ、最後の完全なログ行のWorld時刻を保存。
- 診断wrapper・親側のメモリ監視が増えているため、以前の起動方法との完全同一性は主張しない。

## 結果

| 回 | 終了コード | World秒 | 実処理秒（audit込み） | 最大Working Set MiB |
|---|---:|---:|---:|---:|
| 1 | 0 | 1800 | 134.11 | 523.77 |
| 2 | 0 | 1800 | 134.08 | 523.36 |
| 3 | 0 | 1800 | 133.08 | 523.41 |

各回4,320操作。各回の資源収支・操作重複/重なりなしaudit PASS。
指令・実結果・身体位置の全列SHA-256は3回とも
`8f77cc321b18967d884ce92a28d6ab5b022d4ddaf88ae80d87f03d837b17d5b0`。
ホストメモリ採取時点でも空き物理メモリ約112.6GiB。今回の3回にメモリ不足を示す結果はないが、過去クラッシュ時点のメモリは未採取。

## 過去の障害記録との照合

Windows Application event 1000の直近5時間を読み取ると、同じbundled Pythonの`python312.dll`内で例外`0xc0000005`が4件。別のScoop Pythonでは`ntdll.dll`内の`0xc0000374`が1件あった。3.12側の障害オフセットも全件同じではない。

従って、以前の「例外ログなし終了」も少なくとも一部はOS側にクラッシュとして記録されている。`segment_hit`は落ちた時に実行していたPythonフレームであり、そこがメモリ破壊の発生源とは未確定。Python自体・ネイティブ層・ホスト要因等の切り分けは未完了。

CIの2件のassertion不一致とは別の観測であり、この調査でCIを修正していない。前回の長時間中断記録は撤回せず、今回の完了3回を追加証拠として残す。24時間/複数日での安定性は未検証。

## 再実行

```powershell
& '<固定したPythonの絶対パス>' -X faulthandler -m integrations.lightweight.crash_reproduction --output outputs/<未使用の出力名> --seconds 1800 --trials 3
```

既存出力先は拒否し、失敗した試行も保存して次試行へ進む。子の失敗・report欠落があれば全試行記録後に親もexit 1。診断補助2テストPASS。全体suite/Luantiは未実行。

[環境・実体ハッシュ・結果・行動列ハッシュ・audit](LW_crash_fixed_reproduction.json)。詳細元ログは`outputs/crash_fixed_312_20261007/`。
次に切り分けるなら、一度に変更する条件を一つに絞る（hash seed固定の有無、Python環境など）。今回の非再現だけで修復済みとは扱わない。
