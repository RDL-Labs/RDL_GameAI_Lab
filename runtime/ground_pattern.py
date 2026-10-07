"""Observed-sample groupings, not inferred roads or hidden connectivity."""
from copy import deepcopy
from math import sin,cos,radians,sqrt
from hashlib import sha256
import json


def recognize(p):
    from integrations.lightweight.ground_appearance import validate
    v=p['ground_appearance'];validate(v,p)
    cells=v['cells'];groups=[];remaining={i for i,c in enumerate(cells) if c['status']=='sampled'}
    def neighbors(i):
        a,d=divmod(i,3)
        return [aa*3+dd for aa,dd in ((a-1,d),(a+1,d),(a,d-1),(a,d+1)) if 0<=aa<5 and 0<=dd<3]
    while remaining:
        first=min(remaining);appearance=cells[first]['appearance'];component={first};todo=[first];remaining.remove(first)
        while todo:
            i=todo.pop()
            for j in neighbors(i):
                if j in remaining and cells[j]['appearance']==appearance:
                    remaining.remove(j);component.add(j);todo.append(j)
        ids=sorted(component)
        points=[(cells[i]['distance']*sin(radians(cells[i]['angle'])),cells[i]['distance']*cos(radians(cells[i]['angle']))) for i in ids]
        n=len(points);mx=sum(x for x,z in points)/n;mz=sum(z for x,z in points)/n
        xx=sum((x-mx)**2 for x,z in points)/n;zz=sum((z-mz)**2 for x,z in points)/n;xz=sum((x-mx)*(z-mz) for x,z in points)/n
        disc=sqrt((xx-zz)**2+4*xz*xz);major=(xx+zz+disc)/2;minor=max(0.,(xx+zz-disc)/2)
        band=n>=3 and major>0 and major>=4*minor
        unknown=sorted({j for i in ids for j in neighbors(i) if cells[j]['status']=='occluded'})
        edges=[[i,j] for i in ids for j in neighbors(i) if j in component and i<j]
        payload=dict(appearance=appearance,sample_indices=ids,sample_links=edges,
            shape='sampled_band_candidate' if band else 'sampled_patch' if n>=3 else 'insufficient_shape',
            angular_extent=[min(cells[i]['angle'] for i in ids),max(cells[i]['angle'] for i in ids)],
            distance_extent=[min(cells[i]['distance'] for i in ids),max(cells[i]['distance'] for i in ids)],
            unknown_neighbor_indices=unknown,touches_sampling_boundary=any(i//3 in (0,4) or i%3 in (0,2) for i in ids),
            continuity='between_samples_unverified')
        digest=sha256(json.dumps([v['source'],ids],sort_keys=True).encode()).hexdigest()[:20]
        groups.append(dict(pattern_ref='ground-pattern:'+digest,**payload))
    return dict(rule='observed-ground-group-v1',source=deepcopy(v['source']),coverage=v['coverage'],
        status='unavailable' if not groups else 'patterns_available',groups=groups,
        authority='descriptive sampled grouping; no road identity or action authority')
