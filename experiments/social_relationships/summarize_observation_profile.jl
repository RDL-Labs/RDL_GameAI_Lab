# Inclusive CPU samples, deduplicated per stack. Nested rows must not be added.
using Profile, Serialization, JSON3
profile_summary_root=abspath(ARGS[1])
profile_summary_data,profile_summary_lines=deserialize(joinpath(profile_summary_root,"cpu-profile.jls"))
profile_summary_data=Profile.strip_meta(profile_summary_data)
profile_summary_counts=Dict{String,Int}()
profile_summary_sites=Dict{String,Int}()
profile_summary_groups=Dict{String,Int}()
profile_summary_samples=0
profile_summary_seen=Set{String}()
profile_summary_seen_sites=Set{String}()
for ip in profile_summary_data
    if ip==0
        global profile_summary_samples+=1
        for (label,names) in (
            ("item_observation",("item_visible","item_attention_view!")),
            ("navigation_observation",("rho_observed_map!","observed_cues","movement_observation","skyline_fan","landmark_fan","light_fan","ground_appearance")),
            ("candidate_projection",("mb_chunk_candidates!","mb_exploration_project!","mb_goal_cue_project!","mb_simulate!")))
            any(n->n in profile_summary_seen,names) && (profile_summary_groups[label]=get(profile_summary_groups,label,0)+1)
        end
        if "mb_correspondences" in profile_summary_seen
            for caller in ("mb_chunk_candidates!","mb_exploration_project!","mb_goal_cue_project!","mb_simulate!")
                caller in profile_summary_seen && (profile_summary_groups["correspondences_under_"*caller]=get(profile_summary_groups,"correspondences_under_"*caller,0)+1)
            end
        end
        for k in profile_summary_seen;profile_summary_counts[k]=get(profile_summary_counts,k,0)+1;end
        for k in profile_summary_seen_sites;profile_summary_sites[k]=get(profile_summary_sites,k,0)+1;end
        empty!(profile_summary_seen);empty!(profile_summary_seen_sites)
        continue
    end
    for frame in get(profile_summary_lines,ip,[])
        file=replace(string(frame.file),'\\'=>'/')
        if occursin("/source/src/",file)
            push!(profile_summary_seen,string(frame.func))
            push!(profile_summary_seen_sites,split(file,"/source/")[end]*":"*string(frame.line)*":"*string(frame.func))
        elseif occursin("compiler",file)
            push!(profile_summary_seen,"[compiler]")
        end
    end
end
profile_summary_rows(d)=[(name=k,samples=v,percent=100v/profile_summary_samples) for (k,v) in sort!(collect(d);by=x->(-last(x),first(x)))]
write(joinpath(profile_summary_root,"sample-summary.json"),JSON3.write((samples=profile_summary_samples,
    note="Inclusive stack sample percentages overlap; not exact timers or call counts.",
    functions=profile_summary_rows(profile_summary_counts),sites=profile_summary_rows(profile_summary_sites),groups=profile_summary_rows(profile_summary_groups))))
println("samples ",profile_summary_samples)
for row in first(profile_summary_rows(profile_summary_counts),min(35,length(profile_summary_counts)))
    println(round(row.percent;digits=2),"% ",row.samples," ",row.name)
end
