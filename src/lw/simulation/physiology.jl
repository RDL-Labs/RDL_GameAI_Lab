function advance_physiology!(w,metabolism,guts,food_body;plans=nothing,sleeping_ids=())
        if food_body
            for a in IDS
                guts!==nothing && guts[a].macro_body!==nothing && continue
                before=body_energy(w.bodies[a]);w.bodies[a]=metabolize(w.bodies[a],1.)
                metabolism[a]+=before-body_energy(w.bodies[a])
            end
        end
        if guts!==nothing
            for a in IDS
                bridge=guts[a].macro_body
                spent_before=bridge===nothing ? 0. : bridge.body.spent
                action=plans===nothing || !haskey(plans,a) ? "rest" : get(plans[a],"action","rest")
                w.bodies[a]=digest!(guts[a],w.bodies[a],1.;action,sleeping=a in sleeping_ids)
                if bridge!==nothing
                    # Physical expenditure E; no normalized reserve projection.
                    metabolism[a]+=(bridge.body.spent-spent_before)
                end
            end
        end
end
