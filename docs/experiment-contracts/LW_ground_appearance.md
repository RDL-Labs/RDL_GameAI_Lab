# 地面の局所的な見た目の観測

2026-10-07 / FINITE IMPLEMENTED / 軽量World限定、既定off。
ground_appearance_enabledはground_wear_enabledを要する。

本人の現在姿勢に対し角度-90/-45/0/45/90、距離1/2/4の15点を観測する。
各点はgrass(wear0)、trampled_grass(0<wear<10)、bare_ground(wear>=10)の粗い見た目。
既存World障害物のfootprintが観測線分を遮るとoccluded、appearance=null。
これは保守的な平面遮蔽であり、低い物体越しの精密な地面視認ではない。
遮蔽を含めばcoverage=partial。それ以外はcomplete（指定15点の範囲のみ）。

rule/source/coverage/cellsを検証し、run/epoch/agent/取得時刻/姿勢/観測IDに束縛する。
地面セルのWorld座標、累計通行量、通行者、目的地や経路接続は渡さない。
局所相対角度・距離は取得位置であり、Worldの完全地図ではない。

Runtime本人のobservationsに保存し、再送で判断を再実行しない。
この入力を使う新しい候補・優先規則・Sleep分類・学習contextは追加しない。
既存の地面抵抗は従来通りenergy経由で作用するが、今回の見た目とは別経路。
「道が続いている」「ここを進むべき」「食料に通じる」の解釈は未実装。
Luanti/SensorFrame storeへの統合は今回の範囲外。
