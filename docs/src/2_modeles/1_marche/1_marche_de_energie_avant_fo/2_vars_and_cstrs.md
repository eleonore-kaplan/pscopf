# Variables et Contraintes


## Couper la production (non implémenté)

La variable $P_{cut\_production}[ts,s]$ précise la puissance produite mais qui ne peut etre utilisée à l'instant $ts$ et dans le scénario $s$.
Cette variable pourra servir dans le cas où les unités présentent des $pmin$ induisant des productions excessive. (Aussi, si on impose que les unités limitables soient exploitées à leurs capacités de production disponibles).

Question : localiser par générateur ?

## Couper la consommation (non implémenté)

La variable $P_{cut\_consumption}[ts,s]$ précise la demande qui n'a pas pu être satisfaite à l'instant $ts$ et dans le scénario $s$.

Il faudra faire attention à ce que la penalisation de cette variable soit plus importante que la variable qui coupe la production.

Question : localiser par bus ? (pas intéréssant pour le marché car les contraintes bloquantes sont globales ie EOD)

## Unités Limitables

```math
P_{injected}(gen, ts, s) \forall gen \in LIMITABLES, \forall ts \in TS, \forall s \in S\\
```
est la puissance injectée sur le réseau par l'unité limitable à l'instant $ts$ dans le scénario $s$.

```math
\forall gen \in LIMITABLES, \forall ts \in TS, \forall s \in S\\
0 \le P_{injected}[gen, ts, s] \le min(pmax(gen), uncertainties(gen,ts,s))
```

Les unités limitables sont supposées fatales. Elles produisent à la capacité disponible :
```math
\forall gen \in LIMITABLES, \forall ts \in TS, \forall s \in S\\
P_{injected}[gen, ts, s] = min(pmax(gen), uncertainties(gen,ts,s))
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

## Contrainte EOD
$P_{cut\_production}(ts,s)$


```math
\forall ts \in TS, \forall s \in S, \\

\sum_{bus \in BUSES} uncertainties(bus,ts,s) - P_{cut\_consumption}[(]ts,s]
=
\sum_{gen \in GENERATORS} P_injected[gen,ts,s] - P_{cut\_production}[(]ts,s]
```
