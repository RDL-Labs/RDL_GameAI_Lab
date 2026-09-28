"""Read-only follow-up audit from accepted agent records; no World oracle input."""
import argparse
import gzip
import hashlib
import json
from collections import Counter
from pathlib import Path


def summarize_agent(agent):
    rows = []
    for oid, decision in sorted(agent['decisions'].items(),
                                key=lambda item: agent['observations'][item[0]]['capture_us']):
        observation = agent['observations'][oid]
        command = agent['commands'][oid]
        result = agent['results'][command['operation_id']]
        rows.append(dict(observation_id=oid, capture_us=observation['capture_us'],
                         reason=decision['reason'], action=decision['action'],
                         result=result['status'], acquired=result['acquired'],
                         food_visible=len(observation['food']['visible']),
                         landmark_outcome=decision['landmark']['outcome'],
                         approach=decision['approach'],
                         blocked_targets=decision['blocked_targets']))
    reviews = []
    for index, row in enumerate(rows):
        decision = agent['decisions'][row['observation_id']]
        review = decision['goal_reassessment']
        if not review['triggered']:
            continue
        tail = rows[index:]
        reviews.append(dict(status=review['status'], source=row['observation_id'],
                            rows=tail, result_counts=dict(Counter(r['result'] for r in tail)),
                            reason_counts=dict(Counter(r['reason'] for r in tail)),
                            acquired_count=sum(r['acquired'] for r in tail)))
    return dict(reviews=reviews, observations=len(rows),
                acquired_count=sum(r['acquired'] for r in rows),
                learning_records=len(agent['learning']['records']),
                active_model=agent['active_model'])


def diagnose(archive):
    return dict(schema='l15a-goal-followup-audit-v1', authority='offline diagnostic only',
                runs=[dict(index=i, agents={aid: summarize_agent(a)
                      for aid, a in run['data']['runtime']['exploration']['agents'].items()})
                      for i, run in enumerate(archive['runs'])])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    with gzip.open(args.archive, 'rt', encoding='utf-8') as stream:
        report = diagnose(json.load(stream))
    report['source_sha256'] = hashlib.sha256(args.archive.read_bytes()).hexdigest()
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
