"""Observer-only event log. Full packets and periodic World samples are omitted."""
from copy import deepcopy
from math import hypot
from math import isclose


class EventLog:
    def __init__(self, write):
        self.write=write
        self.last={}
        self.segments={}
        self.metabolism=None

    def flush_metabolism(self):
        if self.metabolism is not None:
            self.write(self.metabolism)
            self.metabolism=None

    def metabolic(self, row):
        duration=row['end_us']-row['start_us']
        rates={a:(row['after'][a]-v)/duration for a,v in row['before'].items()}
        # Actual current hunger boundary is reserve <= 80; zero is saturation.
        bands=lambda values:{a:(v<=80,v<=0) for a,v in values.items()}
        crossing=bands(row['before'])!=bands(row['after'])
        old=self.metabolism
        compatible=bool(old and old['end_us']==row['start_us'] and
            old['after']==row['before'] and old['rate_per_us'].keys()==rates.keys() and
            all(isclose(old['rate_per_us'][a],rate,rel_tol=1e-9,abs_tol=1e-15)
                for a,rate in rates.items()))
        if crossing or not compatible:self.flush_metabolism()
        if self.metabolism is None:
            self.metabolism=dict(type='metabolism_interval',start_us=row['start_us'],
                before=deepcopy(row['before']),rate_per_us=rates,count=0)
        self.metabolism.update(end_us=row['end_us'],after=deepcopy(row['after']))
        self.metabolism['count']+=1
        if crossing:
            self.metabolism['boundary_crossing']=dict(before=bands(row['before']),after=bands(row['after']))
            self.flush_metabolism()

    def flush(self, aid=None):
        for key in list(self.segments):
            if aid is None or aid==key:
                self.write(self.segments.pop(key))

    def emit(self, row):
        kind=row['type']
        if kind=='metabolism':
            self.metabolic(row)
            return
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
        if kind in ('summary','ground_day'):self.flush_metabolism()
        if kind=='summary':self.flush()
        if kind=='manifest':row=dict(row,log_mode='events',log_schema='lw-event-log-v2')
        self.write(row)
