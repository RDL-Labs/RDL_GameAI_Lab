function moving_world(spec)
    w=world(spec.hearing);w.capacity=4096
    for (i,a) in enumerate(IDS)
        w.positions[a]=(Float64(spec.positions[i][1]),Float64(spec.positions[i][2]))
        w.bodies[a]=Body(10.,0.,a=="npc_a" ? 50. : 100.,0.)
    end
    w.obstacles=[RDLMigrationProbe.Circle(o.x,o.z,o.radius) for o in spec.obstacles]
    w
end
