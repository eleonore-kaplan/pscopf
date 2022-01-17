# Objective Function

PSCOPF minimizes the cost of required adjustments :

```math
\begin{aligned}
Min \\

          & \frac{1}{|S|}\sum_{ts;s;branch \in BRANCHES} c_{branch\_slack} P_{branch\_slack\_pos}(branch,ts,s) \\
        + & \frac{1}{|S|}\sum_{ts;s;branch \in BRANCHES} c_{branch\_slack} P_{branch\_slack\_neg}(branch,ts,s) \\
        + & \frac{1}{|S|}\sum_{ts;s;bus \in BUSES} c_{cut\_consumption} P_{cut\_consumption}(bus,ts,s) \\
        + & \frac{1}{|S|}\sum_{ts;s;gen} c_{cut\_production} P_{cut\_production}(gen,ts,s) \\

        + & \frac{1}{|S|}\sum_{ts;s;gen \in LIMITABLES} c_{prop}(gen) c_{lim}(gen,ts,s) \\
        + & \sum_{ts,\\ gen \in IMPOSABLES} c_{start}(gen) B_{is_started}(gen,ts) \\
        + & \frac{1}{|S|}\sum_{ts;s;gen \in IMPOSABLES} c_{prop}(gen) C_{imp\_pos}(gen,ts,s) \\
        + & \frac{1}{|S|}\sum_{ts;s;gen \in IMPOSABLES} c_{prop}(gen) C_{imp\_neg}(gen,ts,s) \\

        + & 10^{-4} P_{reserve\_pos}(ts,s) \\
        + & 10^{-4} P_{reserve\_neg}(ts,s) \\

        + & 10^{-4} \sum_{ts;s;gen \in LIMITABLES} B_{is\_limited}(gen,ts,s) \\
\end{aligned}
```