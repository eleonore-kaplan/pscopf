# Objective Function

Le marché essaye de produire à moindre coût. La fonction objectif consiste à minimiser la somme des coût de production et de démarrage des unités.

```math
\begin{aligned}
Min \\
          & \sum_{ts \in TS;s \in S;\\gen \in GENERATORS} c_{prop}(gen) P_{injected}[gen,ts,s] \\
        + & \sum_{ts \in TS, s \in S;\\ gen \in IMPOSABLES_+\setminus{GRATIS}} c_{start}(gen) B_{start}[gen,ts,s] \\
        + & \sum_{ts \in S;s \in S} penalty_{cut\_consumption} P_{cut\_consumption}(ts,s) \\
        + & \sum_{ts \in S;s \in S} penalty_{cut\_production} P_{cut\_production}(ts,s) \\
\end{aligned}
```