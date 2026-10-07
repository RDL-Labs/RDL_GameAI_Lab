"""Coarse provision observation and initial, explicit sufficiency use rule."""

def observe(count):
    if type(count) is not int or count < 0:
        raise ValueError('food_count')
    return 'none' if count == 0 else 'low' if count <= 2 else 'some' if count <= 5 else 'many'


def assess(band, reserve):
    if band not in ('none', 'low', 'some', 'many'):
        raise ValueError('food_band')
    # Observation is not sufficiency: even many requires eating when hungry.
    if reserve < 80 and band != 'none':
        choice = 'eat'
    elif band in ('some', 'many'):
        choice = 'provisioned_rest'
    else:
        choice = 'existing_activity'
    return dict(rule='personal-food-sufficiency-v1', band=band, choice=choice,
                authority='fixed initial use rule; not learned sufficiency')
