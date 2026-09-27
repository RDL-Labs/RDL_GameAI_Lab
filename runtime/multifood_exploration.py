"""L13W: the same L13V learner/controller with a bounded five-Food observation."""
from .exploration import MULTIFOOD_SCHEMA
from .neighborhood_exploration import NeighborhoodExplorationDay, NeighborhoodExplorationSeries


class MultiFoodExplorationDay(NeighborhoodExplorationDay):
    allow_multifood = True
    configuration_schema = MULTIFOOD_SCHEMA


class MultiFoodExplorationSeries(NeighborhoodExplorationSeries):
    day_type = MultiFoodExplorationDay

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.config["schema"] = MULTIFOOD_SCHEMA
