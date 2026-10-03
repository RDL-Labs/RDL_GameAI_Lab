"""World-time stock replenishment, never an agent-side food oracle."""
DAY_US=64000000


class ResourceRegrowth:
    def __init__(self,days,capacity=12):
        if type(days) is not int or days<1:raise ValueError('regrowth_days')
        if type(capacity) is not int or capacity<1:raise ValueError('regrowth_capacity')
        self.period=days*DAY_US;self.capacity=capacity;self.epoch=0;self.last_us=0

    def advance(self,now,resources):
        if now<self.last_us:raise ValueError('regrowth_clock')
        self.last_us=now;epoch=now//self.period
        if epoch<=self.epoch:return None
        self.epoch=epoch;before=[r['stock'] for r in resources]
        for r in resources:r['stock']=max(r['stock'],self.capacity)
        after=[r['stock'] for r in resources]
        return dict(type='resource_regrowth',capture_us=now,epoch=epoch,period_us=self.period,
            capacity=self.capacity,before=before,stock=after,added=[b-a for a,b in zip(before,after)])
