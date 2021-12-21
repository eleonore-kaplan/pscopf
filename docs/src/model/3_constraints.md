# Problem Constraints

## EOD Constraint

This constraint expresses the balance betwen the electricity supply and demand:

```math
\forall ts \in TS, \forall s \in S, \\
\sum_{gen \in IMPOSABLES} P_{imposable}(gen,ts,s)
+ \sum_{gen \in LIMITABLES} P_{enr}(gen,ts,s)
+ P_{reserve}(ts,s)
= \sum_{bus \in BUSES} load(bus,ts,s)
```

This set of constraints ensures the supply and demand balance for each scenario and at each time step.
This can easily make the problem infeasable.

## Branch Security Constraint

```math
\forall ts \in TS, \forall s \in S, \forall branch \in BRANCHES \\ \quad \\
\begin{aligned}
&- limit(branch,ts,s)\\
&\le \\
& \qquad \sum_{gen \in IMPOSABLES} P_{imposable}(gen,ts,s) ptdf(branch, bus(gen)) \\
+ & \qquad \sum_{gen \in LIMITABLES} P_{enr}(gen,ts,s) ptdf(branch, bus(gen)) \\
- & \qquad \sum_{bus \in BUSES} load(bus,ts,s) ptdf(branch, bus) \\
&\le \\
&limit(branch,ts,s) \\
\end{aligned}
```

This constraint expresses the power limits of the network's branches.
This, actually, represents a thermal real constraint in terms of a power limit constraint.
