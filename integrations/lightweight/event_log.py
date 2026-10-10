"""Observer-only event log. Full packets and periodic World samples are omitted."""
from copy import deepcopy
from math import hypot


class EventLog:
    def __init__(self, write):
        self.write=write
        self.last={}
        self.segments={}

    def flush(self, aid=None):
        for key in list(self.segments):
            if aid is None or aid==key:
                self.write(self.segments.pop(key))

    def emit(self, row):
        kind=row['type']
        if kind in ('working_capture','work_started','hazard_world','territory_world','patrol_world'):
            return
        if kind=='decision':
            p=row['packet'];c=row['command'];aid=c['agent_id']
            selection=row.get('continuous_selection') or {}
            inertia=selection.get('inertia') or {}
            value=dict(model=selection.get('selected'),kind=c['kind'],amount=c.get('amount'),
                phase=row.get('activity_phase'),gate=selection.get('gate'),
                interrupt=inertia.get('interrupt'),hazard=p.get('hazard'),
                reason=(row.get('safety') or {}).get('reason'))
            # Hazard source IDs and clocks change every sample; compare content.
            if value['hazard']:
                value['hazard']={k:v for k,v in value['hazard'].items() if k!='source'}
            if value!=self.last.get(aid):
                self.flush(aid)
                self.write(dict(type='selection_change',agent_id=aid,capture_us=p['capture_us'],
                    observation_id=p['observation_id'],operation_id=c['operation_id'],
                    local_H=inertia.get('H'),**value))
                self.last[aid]=deepcopy(value)
            return
        if kind=='completed':
            c=row['command'];r=row['result'];aid=c['agent_id']
            # Keep a small per-operation receipt for exact conservation/dedup audit.
            self.write(dict(type='completed',command=c,result=r,food_ledger=row['food_ledger']))
            if r['status']=='moved':
                segment=self.segments.get(aid)
                if segment is None:
                    segment=dict(type='movement_segment',agent_id=aid,
                        selection=deepcopy(self.last.get(aid)),start_us=c['capture_us'],
                        first_operation=c['operation_id'],count=0,distance=0.)
                    self.segments[aid]=segment
                segment.update(end_us=r['executed_us'],last_operation=c['operation_id'])
                segment['count']+=1
                segment['distance']+=hypot(r.get('forward',0),r.get('right',0))
            else:
                self.flush(aid)
            return
        if kind=='summary':self.flush()
        if kind=='manifest':row=dict(row,log_mode='events',log_schema='lw-event-log-v1')
        self.write(row)
