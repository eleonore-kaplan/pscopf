# Variables et Contraintes


## Couper la production ?
par générateur pour pouvoir résoudre des infaisabilité RSO ?
$P_{cut\_production}[ts,s]$ ?
$P_{cut\_production}[gen, ts,s]$ ?
$P_{cut\_production}[bus, ts,s]$ ?
## Couper la consommation ?
par bus pour pouvoir résoudre des infaisabilité RSO ?
$P_{cut\_consumption}[ts,s]$ ?
$P_{cut\_consumption}[bus, ts,s]$ ?
## Unités Limitables

```math
P_{injected}(gen, ts, s) \forall gen \in LIMITABLES, \forall ts \in TS, \forall s \in S\\
```
est la puissance injectée sur le réseau par l'unité limitable à l'instant $ts$ dans le scénario $s$.

```math
\forall gen \in LIMITABLES, \forall ts \in TS, \forall s \in S\\
0 \le P_{injected}[gen, ts, s] \le min(pmax(gen), uncertainties(gen,ts,s))
```


## Unités Imposables

```math
P_{injected}(gen, ts, s) \forall gen \in IMPOSABLES, \forall ts \in TS, \forall s \in S\\
```
est la puissance injectée sur le réseau par l'unité imposable $gen$ à l'instant $ts$ dans le scénario $s$.

```math
B_{start}(gen, ts, s) \forall gen \in IMPOSABLES_+, \forall ts \in TS, \forall s \in S\\
```
est une variable binaire indiquant si l'unité imposable $gen$ a été démarrée à l'instant $ts$ dans le scénario $s$.

```math
B_{on}(gen, ts, s) \forall gen \in IMPOSABLES_+, \forall ts \in TS, \forall s \in S\\
```
est une variable binaire indiquant si l'unité imposable $gen$ est démarré à l'instant $ts$ dans le scénario $s$.

Note: Les variables $B_{on}$ et $B_{start}$ ne concerne que les unités ayant une capacité de production minimale non nulle (i.e. $pmin(gen) > 0$) car, pour les autres unités, nous pouvons supposer que l'unité est tout le temps démarré à un niveau de production nul.
#### Contraintes de commitment

```math
\forall gen \in IMPOSABLES_+, \forall ts \in TS, \forall s \in S\\
B_{start}[gen, ts, s] \le B_{on}[gen, ts, s] \\
B_{start}[gen, ts, s] \le 1 - B_{on}[gen, ts-1, s] \\
B_{start}[gen, ts, s] \ge B_{on}[gen, ts, s] - B_{on}[gen, ts-1, s] \\
\text{avec } B_{on}(gen, ts_1-1, s) = initial\_state(gen)
```

#### Capacités de production

```math
\forall gen \in IMPOSABLES_0, \forall ts \in TS, \forall s \in S\\
0 \le P_{injected}[gen, ts, s] \le pmax(gen)
```

```math
\forall gen \in IMPOSABLES_+, \forall ts \in TS, \forall s \in S\\
pmin(gen) B_{on}[gen,ts,s] \le P_{injected}[gen, ts, s] \le pmax(gen) B_{on}[gen,ts,s]
```

#### Contraintes liées à la DP

```math
\forall gen \in IMPOSABLES, \forall ts \in TS, \forall s \in S \\
\begin{aligned}
    & \text{si } firmness\_dp(gen,ts) = DECIDED \\
    & \qquad && P_{injected}[gen, ts, s]  = scheduled\_production(gen,ts) \\
    & \text{si } firmness\_dp(gen,ts) = TO\_DECIDE \\
    & \qquad && P_{injected}[gen, ts, s] = P_{injected}[gen, ts, s1] \\
\end{aligned}
```

#### Contraintes liées à la DMO

```math
\forall gen \in IMPOSABLES_+, \forall ts \in TS, \forall s \in S \\
\begin{aligned}
    & \text{si } firmness\_dmo(gen,ts) = DECIDED \\
    & \qquad && B_{on}[gen, ts, s]  = scheduled\_commitment(gen,ts) \\
    & \text{si } firmness\_dmo(gen,ts) = TO\_DECIDE \\
    & \qquad && B_{on}[gen, ts, s] = B_{on}[gen, ts, s1] \\
\end{aligned}
```

## Différence des injections par rapport aux consignes du marché

```math
\Delta P^{+}[gen, ts, s] \forall gen \in GENERATORS, \forall ts \in TS, \forall s \in S\\
```
est l'augmentation de la puissance injectée sur le réseau par l'unité $gen$ à l'instant $ts$ dans le scénario $s$ par rapport à la consigne du marché.

```math
\Delta P^{-}[gen, ts, s] \forall gen \in GENERATORS, \forall ts \in TS, \forall s \in S\\
```
est la diminution de la puissance injectée sur le réseau par l'unité $gen$ à l'instant $ts$ dans le scénario $s$ par rapport à la consigne du marché.

```math
\forall gen \in GENERATORS, \forall ts \in TS, \forall s \in S \\
\Delta P^{+}[gen, ts, s]  - \Delta P^{-}[gen, ts, s]
=
P_{injected}[gen, ts, s] - p_market(gen,ts,s)
```


## Contrainte EOD


```math
\forall ts \in TS, \forall s \in S, \\

\sum_{bus \in BUSES} uncertainties(bus,ts,s) - \sum_{bus \in BUSES} P_{cut\_consumption}[bus, ts,s]
\\ = \\
\sum_{gen \in GENERATORS} P_{injected}[gen,ts,s] - \sum_{gen \in GENERATORS} P_{cut\_production}[gen,ts,s]
```

ou bien :

```math
\forall ts \in TS, \forall s \in S, \\

\sum_{gen \in GENERATORS} \Delta P^{+}[gen,ts,s]
- \sum_{gen \in GENERATORS} \Delta P^{-}[gen,ts,s] \\
+ p\_market_{cut\_production}[ts,s]
- p\_market_{cut\_consumption}[ts,s]
\\ = \\
\sum_{gen \in GENERATORS} P_{cut\_production}[gen,ts,s]
- \sum_{bus \in BUSES} P_{cut\_consumption}[bus, ts,s]
```




## Contraintes RSO

```math
\forall ts \in TS, \forall s \in S, \forall branch \in BRANCHES \\ \quad \\
\begin{aligned}
&- limit(branch,ts,s) \\
&\le \\
& \qquad \sum_{gen \in GENERATORS} P_{injected}(gen,ts,s) ptdf(branch, bus(gen)) \\
- & \qquad \sum_{gen \in GENERATORS} P_{cut\_production}[gen, ts,s] ptdf(branch, bus(gen)) \\
- & \qquad \sum_{bus \in BUSES} uncertainties(bus,ts,s) ptdf(branch, bus) \\
+ & \qquad \sum_{bus \in BUSES} P_{cut\_consumption}[bus, ts,s] ptdf(branch, bus) \\
&\le \\
&limit(branch,ts,s) \\
\end{aligned}
```

