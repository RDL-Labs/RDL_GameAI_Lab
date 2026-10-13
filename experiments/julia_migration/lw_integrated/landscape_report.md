# Native riparian base landscape

Source128bc68. Reference integrations/lightweight/base_landscape.py,
energy_exploration.py and ground_appearance.py. Same native life entry, no new loop.

--layout riparian generates a sinusoidal stream, finite banks, two elliptical
forest areas, rockland and background grassland. Resistance values are3/1.8/2/2.5/1.5
respectively. Geometry is World-only; agents receive existing local energy rows,
finite appearance samples, food and skyline. Water is traversable, causes effort,
and appears as water. It cannot receive tread wear or reduce resistance through
wear. Dry ground retains existing trail formation/recovery.

Placement preserves the Python conditions: up to100 objects, at most1800 attempts,
material-weighted placement, camp clearance and object spacing. Ten forest-adjacent
food sites are outside16 units of camp; not every tree bears food and their observed
appearance is not labelled with a hidden resource identity. Too few valid sites
explicitly fails generation. No map-edge wall is added.

Julia MersenneTwister produces different layouts than Python for the same numeric
seed. The generator is identified as julia-lw-riparian-mt-v1; frozen spec is authoritative.
This opt-in layout places home at[0,6] as Python base landscape does; sparse stays
unchanged. Low rocks are held in native low_obstacles and require that World option,
consistent with current native obstacle integration. General3D dynamics are absent.

Landscape metadata is preserved and checked in environmental checkpoints, so a
continued World cannot silently change river phase. Same-agent resume remains absent.

Actions38368026817 pending: material/placement/water checks, two seeds each one day,
local ground effort correspondence, skyline and climbing connected, frozen replay.
No long-term living success or full LW parity is claimed by this addition.
