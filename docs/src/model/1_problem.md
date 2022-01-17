# PSCOPF Optimization Problem

PSCOPF tries to solve a probabilistic Optimal Power Flow problem.

Given a power network, multiple scenarios of loads and production planning,
 PSCOPF tries to retrieve the optimal solution that minimizes the cost of the
 adjustments to apply while satisfying all the considered scenarios.

## Input Parameters

Each PSCOPF launch is done at a given date, denoted by $ech$ and concerns one or many interest timesteps denoted $TS=\{ts_1,...ts_n\}$.

### Uncertainties :

Describes the possible production scenarios.

A production scenario is a set of production values and load values
of each power station or bus
at multiple time steps
seen from multiple horizons at datepoints $ech$.

These will be denoted as : $prod(unit, ech, ts, s)$ or $load(bus, ech, ts, s)$ where
 unit is a power station,
 ech is the horizon datepoint,
 ts is a time step,
 s is a scenario,
 and bus is one of the network's buses.

In this documentation, we will denote by $TS$ the set of considered time steps in the model
and by $S$ the set of plausible scenarios we consider.

### Planning :

Describes the scheduled/forecast production value
 of each power station
 at multiple time steps
 for a given fixed horizon.
These values will be denoted $prev(unit, ech, ts)$.

### Units

Describes the power stations treated in the problem.

Each power station (aka, unit), is characterised by :
- a name
- a minimum production :
    The minimum capacity produced by the power station whenever it is working,
    denoted by $p_{min}(unit)$ (0 for limitable units)
- a maximum production :
    The maximum capacity that can not be exceeded by the power station,
    denoted by $p_{max}(unit)$
- a starting fixed cost :
    This is the cost of starting the power station,
    denoted $c_{start}(unit)$
- a variable cost :
    This will imply the cost of running the power station and will be proportional to the stations production,
    denoted $c_{prop}(unit)$
- a DMO (fr. Delai de Mise en Oeuvre):
    Represents the time required between the decision to start (or even change the production level of) a unit
    and the moment the power becomes really available in the network.
    denoted $dmo(unit)$

### Unit Type and Location

Describes the units' types and their locations (which bus they are assigned to).

PSCOPF handles two types of units:
- Imposable :
    These are ordinary power stations that we can control.
    i.e. We can set their production level at wish at any level between their minimum and maximum production level (or shut them down).
- Limitable :
    These are units, mainly linked to renewable energy production,
    for which only the maximum production capacity can be set
    whilst the actual production is decided by other uncertain/non-predictable factors.

Each unit can only be assigned to a single bus.

### PTDF

The Power Transfer Distribution Factors matrix.

### Limits

The power limits of each of the network branches, denoted by $limit(branch)$.

### [MISSING Reserves]

Reserves are an optimization lever.
Their level can be controled by the optimizer (i.e. decision variable, c.f. TODO:LINK_TO_DVAR_RESERVE).
They are delocalized. They can be positive or negative.
Their minimum and maximum levels are [MISSING] input parameters.


## Output

TODO

need to check : impositions.txt and limitations.txt

transcription of the decision variables :
- production levels of the units
- which units were imposed
- which units were started
- used reserves
- branch flow status
- severed power
- cut production, cut consumption, increased branch limits,...

