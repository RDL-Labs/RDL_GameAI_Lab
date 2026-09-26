# OBS-6 Integrated Life Regression Evidence

## Real Luanti Vertical

```powershell
./integrations/luanti/scripts/test-observation-integration.ps1 -LuantiRoot D:\luanti
```

Observed on 2026-09-26:

```text
OBS6 SENSORY: agents=2 channels=3 rejections=0 decisions_unchanged=true
OBS6 LIFE PASS: agents=2 pickups=2 deposits=2 results=2 radius_counts=A:2,B:1
```

The same World run produced separate `vision_local`, `vision_distant`, and
`audition` histories for both agents. Each agent retained at least one finite
distant feature and one action-sound detection. Local every-tick samples and
distant four-tick samples included nonmatching capture times. Every stored
frame matched its delivery agent, no frame was rejected, and no capture end
advanced beyond its sampled World tick boundary.

The ordinary sensory-disabled RW2 harness was rerun afterward:

```text
MULTI LIFE PASS: agents=2 pickups=2 deposits=2 results=2 radius_counts=A:2,B:1
```

Therefore the integrated SensorFrames did not change the existing finite Food
decisions or accepted results. This evidence does not establish sensory fusion,
meaning attribution, sound-driven orientation, long-running retention, or
sensor-informed action.

Regression after integration:

- full Python suite: `328` tests passed, `46` intentionally skipped
- real Luanti OBS-3 distant observation: PASS
- real Luanti OBS-4C audition window boundaries: PASS

