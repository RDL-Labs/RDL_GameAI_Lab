# 暫定固定: 全員の名前と外見を既知として初期記憶を配る研修ショートカット。
# scene.peer_identity_roster未指定ならOFF。world featuresと本人記憶は別コピー。
# 診断接続のみで通常の行動は変更しない。将来は出会い・名前教示の経験へ置換。
function configured_peer_identity_memory(actor,roster)
    haskey(roster,actor) || error("identity roster owner missing")
    D("names"=>D(String(peer)=>String(row["name"]) for (peer,row) in pairs(roster) if String(peer)!=actor),
      "features"=>D(String(peer)=>Float64.(row["features"]) for (peer,row) in pairs(roster) if String(peer)!=actor),
      "counts"=>D(),"records"=>Any[],"current"=>Any[],"observations"=>0)
end
