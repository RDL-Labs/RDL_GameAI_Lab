"""Current provision constraint, with no future food availability oracle."""
import json
from pathlib import Path
from .integrated_social_campaign import OPTIONS,audit,compact_report
from .timed_harvest import run


def main():
    root=Path('outputs/food_retention');root.mkdir(parents=True,exist_ok=True)
    options=dict(OPTIONS,seed=20261005,body_scene='social_shared',personal_food=True,
                 hunger_enabled=True,body_method_field=True,food_retention=True)
    path=root/'enabled.jsonl';run(path,**options)
    result=compact_report(dict(enabled=dict(options=options,audit=audit(path))))
    reviews=[]
    with path.open(encoding='utf8') as source:
        for line in source:
            row=json.loads(line)
            if row['type']=='decision':
                choice=row.get('refusal_choice') or {}
                if choice.get('retention'):
                    reviews.append(dict(agent=row['packet']['agent_id'],source=row['packet']['observation_id'],choice=choice))
    result['enabled']['retention_reviews']=reviews
    (root/'report.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(summary=result['enabled']['audit']['summary'],
                         actions=result['enabled']['audit']['actions'],reviews=len(reviews))),flush=True)
    return result


if __name__=='__main__':main()
