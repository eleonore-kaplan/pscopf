# Objective Function

PSCOPF minimizes the cost of required adjustments :

```math
\begin{aligned}
Min \qquad 
          & \frac{1}{|S|}\sum_{ts;s;gen \in LIMITABLES} c_{prop}(gen) c_{lim}(gen,ts,s) \\
        + & \sum_{ts,\\ gen \in IMPOSABLES} c_{start}(gen) B_{is_started}(gen,ts) \\
        + & \frac{1}{|S|}\sum_{ts;s;gen \in IMPOSABLES} c_{prop}(gen) C_{imp\_pos}(gen,ts,s) \\
        + & \frac{1}{|S|}\sum_{ts;s;gen \in IMPOSABLES} c_{prop}(gen) C_{imp\_neg}(gen,ts,s) \\
        + & 10^{-2} \sum_{ts;s;gen \in LIMITABLES} B_{is\_limited}(gen,ts,s) \\
\end{aligned}
```