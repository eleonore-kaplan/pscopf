# Architecture

## Introduction

Cette section tente de découper la problématique traitée en définissant plusieurs composantes.
Chaque composante a une responsabilité.
Une responsabilité peut être définie par le sous-problème intermédiaire que la composante doit résoudre, des entrées et des sorties de ce sous-problème.
Chaque composante doit résoudre le sous-problème qui lui est assigné indépendamment des autres composantes pourvu que les bonnes entrées lui soient fournies.

L'idée est de pouvoir modifier le fonctionnement interne de chacune de ces composantes.
 Ceci permettra de modifier le fonctionnement interne d'une composante pour s'adapter à un processus de gestion simulé sans avoir à modifier les autres composantes. Ce qui permettra aussi une réutilisation des composantes.

## Différents Blocs

Notons que les composantes présentées ci-dessous peuvent elle-même être découpée en de plus petites composantes.
Par exemple, une composante de génération d'incertitudes sur l'ensemble du réseau pourrait être constituée de plusieurs composantes générant chacune les incertitudes d'une unité de production ou d'un point de consommation.

### Bloc de Génération des échéances

![Bloc de génération des échéances](../figs/bloc_gen_ech.png)

Le lancement des calculs se faisant à plusieurs échéances, une composante pourrait être dédiée à la determination de ces échéances de lancement.
Le générateur d'échéances peut suivre sa propre logique de génération des échéances : Par exemple, une discrétisation de l'espace pour avoir des échéances toutes les 5 minutes. Ou encore, une determination des échéances en fonction des attributs des unités de production présentes sur le réseau.
Les blocs que nous définiront par la suite devront fonctionner indépendamment du choix du fonctionnement de la composante de génération des échéances. C'est à dire qu'ils n'imposeront pas de contraintes sur les échéances devont être simulées mais qu'ils se baseront sur les échéances effectivement générées.

### Bloc de Génération des incertitudes

![Bloc de génération des incertitudes](../figs/bloc_gen_incertitudes.png)

Dans le cadre de ce travail, nous supposons que les incertitudes sur les niveaux de consommation et sur les capacités de production des unités renouvelables se précisent au fur et à mesure que nous nous rapprochons du temps réel.
Nous avons donc besoin d'une réalisation de ces incertitudes à chaque échéance de lancement.
Cette composante assure la génération de plusieurs scénarios d'incertitudes vue d'une échéances donnée pour une ou plusieurs dates d'intérêts.

La responsabilité du générateur d'incertitudes se résume à la génération d'un nombre demandé de scénarios, pour les dates d'intérêt demandée. Les scénarios générés itérativement à des échéances différentes seront donc indépendantes. De plus, c'est un autre composant qui doit s'assurer de la cohérence du nombre de scénario tout au long du lancement.

### Bloc marché

![Bloc du marché](../figs/bloc_marche.png)

Ce bloc représente les différents marchés à simuler. Ces fonctionnements internes dépenderont du processus de gestion envisagé mais sa responsabilité principale est de fixer un planning de production qui assurerait les contraintes d'offre et de demande (EOD).
Pour celà il dispose d'une vision de l'état du réseau.
C'est le marché lui-même qui décidera quels données du réseau il a besoin de regarder (s'il a besoin de regarder les décisions TSO, les niveaux de réserve,...) pour bien assurer sa responsabilité.

### Bloc TSO

![Bloc du TSO](../figs/bloc_tso.png)

Ce bloc simulerait le responsable du réseau : Il considérerait une situation du réseau en entrée décrivant les incertitudes sur le réseau ainsi que les choix des marchés. Le TSO répondra à cette situation d'entrée, en émettant des décisions d'imposition et de limitation. La principales résponsabilité du TSO est d'assurer les contraintes réseau pour celà il dispose d'une réserve, en plus des unités de production.

### Bloc de Démarrage des unités

![Bloc du TSO](../figs/bloc_dmo.png)

Ce bloc est responsabile du respect des DMO et des DPs dans le planning reflécté par la situation du réseau. Il considère une ou plusieurs situations du réseau en entrée, les aggrège pour n'en fournir qu'une situation mise à jour qui respecte les contraintes de démarrage des unités de production.


## Le réseau

### Description du réseau brut

Le réseau électrique peut être vu comme un graphe. Un point/sommet de ce graphe est une localisation appelées _bus_ ou _noeud_. Les arêtes reliant ces noeuds sont appelées des _branches_.

Une _branche_ est définie par les deux bus qu'elle relie et par une limite maximale de production d'électricité pouvant circuler sur la branche.

A un instant donné, un _bus_ peut être décrit par un niveau de production et un niveau de consommation d'électricité. Il peut comprendre une ou plusieurs composantes du réseau d'électricité à savoir : des unités imposables et/ou des unités limitables voire de la réserve localisée.

Dans le cadre de ce travail, nous considérons que nous disposons d'un certain niveau de réserve. Cette réserve est délocalisée. Une clé de répartition guidée par les coefficient de la PTDF décidera indirectement de cette localisation.

### Description de la situation du réseau

Le réseau peut etre décrit grace à :

- état du réseau : unités démarrées, en démarrage, éteintes
- planning prévisionnel du marché
- planning prévisionnel du TSO

<!-- ![Bloc du TSO](../figs/network.png) -->

## Schéma Général

L'idée derrière cette notion de bloc de responsabilité est de pouvoir enchaîner ces blocs de plusieurs façon afin de représenter des processus de gestion différents.

Ci-dessous un exemple d'enchaînement des blocs :

<!-- ![Bloc du TSO](../figs/bloc_enchainement.png) -->
