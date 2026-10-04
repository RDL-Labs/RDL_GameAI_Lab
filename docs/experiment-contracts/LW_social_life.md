# 探索・食事・通信・夜間Sleepの有限統合

2026-10-04。基準ff94d44。既存 `timed_harvest.run` のopt-in `social_mode=enabled`。
EnergyWorld / EnergyAgentを拡張し、既存BodyScheduler・昼夜・探索・帰還・Sleepを使用する。
別の夜間シミュレーターへ個体を転送せず、位置・身体・在庫は日をまたいで連続する。

## 在庫と身体

地面stock、各個体inventory、共通拠点stock、消費数を操作別台帳に記録。
pickup/give/deposit/take/eatは同じinventoryを使う。本人の所持判断も実在庫観測を使い、
過去のpickup件数から所持数を再構成しない。既存のpickup-IDベースunloadは統合モードで使わない。
したがって旧returns件数を新depositの受入指標としない。drop・重量別品目の追跡は未統合。

共通拠点(0,6)はWorldのみが保持し、範囲1.25かつ視認可能な場合にstockを観測・利用できる。
譲渡も採取と同じ簡易接触範囲1.25かつ非遮蔽。以前の専用通信fixtureの0.6は変更しない。
他者の表示は食料保持の有無のみ。正確な在庫数・内部reserveを他者へ公開しない。

基礎消費proxyは経過1秒につきreserve 0.25。停止・通信・睡眠中にも同じように進む。
観測回数では加算せず、同時刻advanceは冪等。従来の移動消耗・休息回復に伴う消費は別途適用。
これは生理モデル/実時間の飢餓速度ではない。0で止め、死亡や不可逆損傷を追加しない。

## 行動権限

探索とsocial操作は同じ個体別schedulerで1秒操作として排他実行する。
実行時にも期限・姿勢・範囲・在庫・元要求を検査する。
通信操作をwait成功として報告しない。上書きされた移動methodのtrialを除き、Hを誤解消しない。
共有stock最後の1個を同時に要求した場合も、実行順で1個だけ移る。

初版の調停は固定優先規則：既存安全/身体対応/期限を守り、受信への応答、
reserve<80で食事/備蓄利用/援助要求、それ以外は既存探索・帰還。
夜間最後の4秒は既存の休息へ戻す。全社会行動を汎用H候補へ移したわけではない。
声による遠隔救助への移動、見えない相手への要求、交換、強奪、不在探索は未統合。
警告/撤回の実行経路は共有するが、本比較で自発的なreachの候補は生成しない。

## 本人別経験とSleep

本人の要求IDと相手を結合し、given/refuse/期限内応答未観測を別々に保存。
要求自体が実行されなかった場合は `request_not_executed` とし期待学習から除外する。
期限は要求観測から5秒。明示拒否と無応答のevidenceは同一にしないが、
初版の援助期待更新では両方を「援助未観測」と数える。相手の意図はunknown。

既存harvest_sleepが実際のnight waitを確認してcompletedになったときだけ、
そのSleep開始以前の本人の要求結果から局所援助期待を採用する。
式は `(1+given件数)/(2+終了要求数)`。最大192件、単位は独立の要求IDであり、
独立Episodeや因果的な試行と同一視しない。密な繰返し要求による偏りは残る。
再観測、再送、別Sleepで同じ要求の支持を追加しない。本人以外の記録は拒否。
canonical T1/M_Bへの採用ではなく、既存夜間処理に追加した未検証の局所期待モデル。

既存cross-action Sleep reviewにも本人のsocial_observation/social_intentを保存。
生の観測と採用した期待を区別する。次の相手選択は現在見える食料保持者だけから選ぶ。
`social_adopt=False` は記録と身体とSleepを維持し、この局所期待の採用だけ止める対照。

## 3日比較

A/B/Cを既知の同じ拠点メンバーとする。初期携行食料A=0/B=2/C=2、地面12個、
reserve A=30/B=C=90。近接から開始し、拠点への日次転送はしない。
Bのshare=false、Cのshare=trueは実験用固定設定で、性格学習の成果ではない。
social_campではB/Cが携行食料を自動depositしない。social_sharedではdepositする。
主比較は同一social_campで採用なし/あり。shared条件は別の備蓄方針比較。
台帳は通信1024操作・期待192記録の有限容量で、長期無制限運転は未検証。

再実行: `python -m integrations.lightweight.social_life_comparison`
CLIでは `--days 3 --no-return-target --body-mode enabled --energy-mode enabled
--selection-mode continuous --sleep-learning --social-mode enabled --body-scene social_camp
--return-completion-mode enabled --orientation-mode enabled --output outputs/social.jsonl`。
