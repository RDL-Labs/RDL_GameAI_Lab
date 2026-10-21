"Decision from the current observation, without learned state."
struct StatelessPolicy{F}
    decide::F
end
"Decision with explicitly owned memory; world access is not passed to the policy."
struct StatefulPolicy{F,M}
    decide::F
    memory::M
end
choose(p::StatelessPolicy,observation)=p.decide(observation)
choose(p::StatefulPolicy,observation)=p.decide(p.memory,observation)
