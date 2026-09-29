# Initial sky orientation v1

状態: FINITE LIGHTWEIGHT IMPLEMENTED。Luanti未接続。

初期能力として昼の太陽・影相当／夜の星相当を共通基準方位へ読み替えた入力を生成する。
天体描画なし。64秒の仮想日で56秒以降を夜とする。Worldの取得時yawから基準方位の身体相対角を30度に量子化し、中心と半幅15度を渡す。
固定量子化であり独立ノイズではない。繰り返し取得だけでは量子化幅内を精密化しないが、能動回転による精度推定を一般に防ぐ保証ではない。
空は昼夜とも利用可能という簡略条件。遮蔽・天文学・月は扱わない。unavailable入力も受理する。

run/個体/観測ID/取得時刻/姿勢参照を束縛し、再送でも同じ入力・commandを保持する。
正確なyaw、位置、資源や拠点の方位は入力に含めない。方位基準はWorld内の固定方向であり地理的な北の精密モデルではない。

consumerは既存food_goal bounded_rescanだけ。既存の権限で90度旋回を行うと決まった場合、
本人の同日直近最大256観測と現在観測から12方向の取得回数を数え、左右90度先のうち回数が少ない側を選ぶ。同数は従来の右。
これは方位を利用する固定初期規則であり、採用M_Bや学習した経路ではない。
取得回数は訪問場所数でも網羅した視野面積でもない。並進後も同じ方向区分に数えるが、過去の対象の現在方向を推定しない。

既存の1日最大4見回し枠、探索phase、待機理由による許可を維持する。移動・pickup・夜間・帰還を上書きしない。
unavailableなら従来の右旋回へ戻す。地面partialをcompleteに変えない。
初期モードはdisabled、CLI --orientation-mode enabledで有効化。モードはrun固定。

比較: seed20260930、A/B/C、3日、左右left、goal閾値2、両goal mode有効、skyline subrays有効、資源有限、終了便数なし。
Evidenceと試験は [記録](../experiment-evidence/LW_initial_orientation_evidence.md) を参照。
