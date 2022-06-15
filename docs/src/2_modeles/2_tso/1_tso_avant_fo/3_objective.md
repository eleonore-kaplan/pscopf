# Objective Function

Le marché essaye de produire à moindre coût. La fonction objectif consiste à minimiser la somme des coût de production et de démarrage des unités.

```math
\begin{aligned}
Min \\
          & \sum_{gen \in GENERATORS} \Delta P^{+}[gen,ts,s]
        + & \sum_{gen \in GENERATORS} \Delta P^{-}[gen,ts,s] \\
        + & \sum_{bus \in BUSES, ts \in TS, s \in S} penalty_{cut\_consumption} P_{cut\_consumption}[bus,ts,s] \\
        + & \sum_{gen \in GENERATORS, ts \in TS;s \in S} penalty_{cut\_production} P_{cut\_production}[gen,ts,s] \\
\end{aligned}
```

puis,

```math
\begin{aligned}
Min \\
          & \sum_{ts \in TS;s \in S;\\gen \in GENERATORS} c_{prop}(gen) P_{injected}[gen,ts,s] \\
        + & \sum_{ts \in TS, s \in S;\\ gen \in IMPOSABLES_+\setminus{GRATIS}} c_{start}(gen) B_{start}[gen,ts,s] \\
        + & \sum_{bus \in BUSES, ts \in TS, s \in S} penalty_{cut\_consumption} P_{cut\_consumption}[bus,ts,s] \\
        + & \sum_{gen \in GENERATORS, ts \in TS;s \in S} penalty_{cut\_production} P_{cut\_production}[gen,ts,s] \\
\end{aligned}
```

$GRATIS$ est l'ensemble des unités pour lesquels le coût de démarrage a déjà été payé.
Souvent, Il s'agirat des unités démarré avant l'échéance courante ou des unité démarré par le marché à l'échéance considérée.
