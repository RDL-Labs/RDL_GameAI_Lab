# 暫定固定の世界規則：離乳前は出生位置の巣穴内。掘削/入口/内部地形は省略。
# enabled=true（既定）、繁殖OFFでは無効。設定をfalseにすると従来の草上待機。
# 視覚と捕獲だけを遮断し、授乳・飢餓・匂いは維持。離乳時に自動的に地上へ出る。
# 将来は穴への出入りと観測可能な入口を持つ環境/行動に置換する。
const RABBIT_BURROW=(enabled=true,rule="dependent-young-inaccessible-at-birth-site")
configured_rabbit_in_burrow(s,i,t)=RABBIT_BURROW.enabled && s.life!==nothing &&
    s.life.mother[i]>0 && dependent(s.life,i,t) &&
    (!configured_rabbit_self_feeding(s,i,t) || hypot(s.animals.x[i]-s.life.nest[i][1],s.animals.z[i]-s.life.nest[i][2])<=RABBIT_JUVENILE_GROWTH.burrow_radius)
