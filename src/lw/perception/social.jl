function observe(w,a)
    D("self_id"=>a,"body"=>bodydict(w.bodies[a]),"inventory"=>w.inventory[a],
      "others"=>[D("ref"=>b,"holding_food"=>w.inventory[b]>0) for b in IDS if contact(w,a,b)],
      "messages"=>deepcopy([m for m in w.inbox[a] if 0<=w.seconds-m["time"]<3]))
end
