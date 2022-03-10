# Notations


 $S$ : ensemble des scénarios considérés

 $TS$ : ensemble des dates d'intérêts. La première date d'intérêt sera noté $ts_1$

 $LIMITABLES$ : ensemble des générateurs limitables. Ces générateurs ont forcément une capacité minimale nulle et n'ont pas de coût de démarrage

 $IMPOSABLES_+$ : ensemble des unité imposables ayant une capacité de production minimale non nulle

 $IMPOSABLES_0$ : ensemble des unité imposables ayant une capacité de production minimale nulle

 $IMPOSABLES = IMPOSABLES_0 \cup IMPOSABLES_+$ : ensemble des unité imposables. 

 $GENERATORS = IMPOSABLES \cup LIMITABLES$ : ensemble des générateurs. 

 $BUSES$ : ensemble des bus du réseau

  $BRANCHES$ : ensemble des branches du réseau




 $uncertainties(bus,ts,s)$ : valeur de la consommation (demande) du bus $bus$ à la date d'intérêt $ts$  dans le scénario $s$

 $uncertainties(gen,ts,s)$ valeur de la production disponible de l'unité limitable $gen$ à la date  d'intérêt $ts$ dans le scénario $s$

 $pmin(gen)$ : capacité de production minimale du générateur $gen$

 $pmax(gen)$ : capacité de production maximale du générateur $gen$

 $initial\_state(gen)$ : état initial du générateur $gen$ à l'instant précédant $ts_1$ (état ON/OFF)

 $scheduled\_production(gen,ts)$ : la production déjà décidé pour le générateur $gen$ à la date  d'intérêt $ts$

 $scheduled\_commitment(gen,ts)$ : état déjà décidé pour le générateur $gen$ à la date d'intérêt $ts$

 $firmness\_dp(gen,ts)$ : niveau de fermeté de la décision du niveau de production pour le générateur

 $gen$ pour la date d'intérêt $ts$

 $firmness\_dmo(gen,ts)$ : niveau de fermeté de la décision de commitment pour le générateur $gen$ pour  la date d'intérêt $ts$
