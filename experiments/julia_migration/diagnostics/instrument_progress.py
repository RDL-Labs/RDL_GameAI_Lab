from pathlib import Path
import sys
p=Path(sys.argv[1])/'experiments/julia_migration/lw_day/run.jl'
s=p.read_text()
anchor='    for sec in 0:days*div(clock.day_us,1_000_000)-1\n'
assert s.count(anchor)==1
hook='''    progress_path=get(ENV,"LW_PROGRESS_PATH","")
    progress_io=isempty(progress_path) ? nothing : open(progress_path,"a")
    progress_started=time_ns()
    function emit_progress(sec,stage)
        progress_io===nothing && return
        completed=sum(sum(values(counts[a])) for a in IDS)
        println(progress_io, time(), '\\t', (time_ns()-progress_started)/1e9, '\\t', sec, '\\t', div(sec,div(clock.day_us,1_000_000))+1, '\\t', completed, '\\t', stage, '\\t', Sys.maxrss())
        flush(progress_io)
    end
'''
s=s.replace(anchor,hook+anchor+'        sec%60==0 && emit_progress(sec,"tick_begin")\n')
anchor2='        obs=Dict(a=>observe(w,a) for a in IDS)\n'
assert s.count(anchor2)==1
s=s.replace(anchor2,'        sec%60==0 && emit_progress(sec,"observation_begin")\n'+anchor2)
anchor3='        w.seconds=sec+1\n'
assert s.count(anchor3)==1
s=s.replace(anchor3,'        sec%60==0 && emit_progress(sec,"execution_begin")\n'+anchor3)
anchor4='    ground_wear && advance_wear!(wear,wear_offset+Int(days*clock.day_us))\n'
assert s.count(anchor4)==1
s=s.replace(anchor4,'    emit_progress(days*div(clock.day_us,1_000_000),"loop_complete")\n    progress_io===nothing || close(progress_io)\n'+anchor4)
p.write_text(s)
