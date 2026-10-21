function advance_physiology!(w,metabolism,guts,food_body)
        if food_body
            for a in IDS
                before=w.bodies[a].reserve;w.bodies[a]=metabolize(w.bodies[a],1.)
                metabolism[a]+=before-w.bodies[a].reserve
            end
        end
        if guts!==nothing
            for a in IDS; w.bodies[a]=digest!(guts[a],w.bodies[a],1.); end
        end
end
