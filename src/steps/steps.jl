#NOTE IMPORTANTE:
# Il reste une question sur le démarrage/arret des unités : 
# - besoin de se baser sur un état juste avant la date d'intérêt
# - et besoin aussi de regarder mes anciennes décisions si j'ai allumé une unité

#responsabilité manquante : qui s'occupe de l'écriture des rapports/fichiers : chaque étape au fure et à mesure ou tout à la fin ?

struct OptimResult end


################################################################################
####       TSO
################################################################################
abstract type  AbstractTSO <: AbstractRunnable  end

"""
utilisé dans les trois modes
Prend des décisions en se référençant à une situation équilibrée par le marché
N'utilise pas la reserve ?
"""
struct TSOOutFO <: AbstractTSO
end
function run(step::TSOOutFO, context::PSCOPFContext)
    println("TSOOutFO à l'échéance ", get_current_ech(context))
    println("\tJe me référencie au précédent planning du marché pour les arrets/démarrage et l'estimation des couts : ", get_last_market_planning(context))
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage : ", get_last_tso_planning(context))
    #D'ou la nécessité du bloc orange qui va fournir un état réel du réseau sur lequel se basera le TSO (mais pas le marché hors fenêtre opérationnelle)
    return #result
end
function update!(context::PSCOPFContext, result)
    println("\tJe mets à jour le planning tso: ", get_last_tso_planning(context),
            " en me basant sur les résultats d'optimisation.")
    println("\tet je ne touche pas au planning du marché")
end

"""
utilisé pour le mode 3:
Prend des décisions fermes vu que c'est la dernière execution du TSO
Décide de la reserve
"""
struct TSOAtFO <: AbstractTSO
end
function run(step::TSOAtFO, context::PSCOPFContext)
    println("TSOAtFO à l'échéance ", get_current_ech(context))
    println("\tJe me référencie au précédent planning du marché pour les arrets/démarrage et l'estimation des couts : ", get_last_market_planning(context))
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage : ", get_last_tso_planning(context))
    println("\tC'est le dernier lancement du tso => le planning TSO que je fournie doit etre ferme")
    return #result
end
function update!(context::PSCOPFContext, result)
    println("\tJe mets à jour le planning tso: ", get_last_tso_planning(context),
            " en me basant sur les résultats d'optimisation.\n")
    println("\tJe ne touche pas au planning du marché (ou si?)")
end

"""
utilisé pour le mode 1:
Prend des incertitudes non équilibrées (mode 1 => plus de marché dans la FO)
Décide de la reserve
"""
struct TSOInFO <: AbstractTSO
end
function run(step::TSOInFO, context::PSCOPFContext)
    println("TSOInFO à l'échéance ", get_current_ech(context))
    println("\tJe me référencie au planning du marché du début de la FO pour les arrets/démarrage et l'estimation des couts : ", get_last_market_planning(context))
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage : ", get_last_tso_planning(context))
    return #result
end
function update!(context::PSCOPFContext, result)
    println("\tJe mets à jour le planning tso: ", get_last_tso_planning(context),
            " en me basant sur les résultats d'optimisation.\n")
    println("\tJe ne touche pas au planning du marché : C'est le même planning qui me servira de référence")
end

"""
utilisé pour le mode 2:
Prend des incertitudes pas forcément équilibrées
Décide de la reserve
Simule un marché d'équilibrage
"""
struct TSOBiLevel <: AbstractTSO
end
function run(step::TSOBiLevel, context::PSCOPFContext)
    println("TSOBiLevel à l'échéance ", get_current_ech(context))
    println("\tJe simule un marché d'équilibrage pour le pas suivant")
    println("\tJe me référencie au planning du marché du début de la FO pour les arrets/démarrage et l'estimation des couts ?")
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage ?")
    return #result
end
function update!(context::PSCOPFContext, result)
    println("\tJe mets à jour le planning tso: ", get_last_tso_planning(context),
            " en me basant sur les résultats d'optimisation.\n")
    println("\tJe ne touche pas au planning du marché?")
end

################################################################################
####       MARKET
################################################################################
abstract type  AbstractMarket <: AbstractRunnable  end

"""
utilisé pour les trois modes :
Ne regarde pas le planning du TSO
"""
struct MarketOutFO <: AbstractMarket
end
function run(step::MarketOutFO, context::PSCOPFContext)
    println("MarketOutFO à l'échéance ", get_current_ech(context))
    println("\tJe me base sur le précédent planning du marché pour les arrets/démarrage des unités : ", get_last_market_planning(context))
    println("\tJe ne regarde pas le planning du TSO.")
    return #result
end
function update!(context::PSCOPFContext, result)
    println("\tJe mets à jour ce même planning marché: ", get_last_market_planning(context),
            " en me basant sur les résultats d'optimisation.",
            " et je ne touche pas au planning TSO.")
end

"""
utilisé pour le mode 1:
Dans le mode 1, le marché ne s'écecutera plus dans la FO => besoin de décisions fermes
"""
struct MarketAtFO <: AbstractMarket
end
function run(step::MarketAtFO, context::PSCOPFContext)
    println("MarketAtFO à l'échéance ", get_current_ech(context))
    println("\tJe me base sur le précédent planning du marché pour les arrets/démarrage des unités : ", get_last_market_planning(context))
    println("\tJe ne regarde pas le planning du TSO.")
    println("\tC'est le dernier lancement du marché => je prends des décision fermes.")
    return #result
end
function update!(context::PSCOPFContext, result)
    println("\tJe mets à jour le planning du marché: ", get_last_market_planning(context),
            " en me basant sur les résultats d'optimisation.", #step.result
            " et je ne touche pas au planning du TSO")
end

"""
utilisé pour les modes 2 et 3
Dans le mode 2 : je considère le planning du TSO
Dans le mode 3 : je considère le planning du marché
"""
struct MarketInFO <: AbstractMarket
end
function run(step::MarketInFO, context::PSCOPFContext)
    println("MarketInFO à l'échéance ", get_current_ech(context))
    println("\tJe me base sur le dernier planning disponible (marché ou TSO) pour les arrets/démarrage des unités") #besoin de récupérer le dernier planning
    println("\tJe ne regarde pas le planning du TSO.")
    println("\tC'est le dernier lancement du marché => je prends des décision fermes.")
    return #result
end
function update!(context::PSCOPFContext, result)
    println("\tJe mets à jour le planning du marché: ", get_last_market_planning(context),
            " en me basant sur les résultats d'optimisation.", #step.result
            " et je ne touche pas au planning du TSO")
end

################################################################################
####       Utils
################################################################################

struct Assessment <: AbstractRunnable
end
function run(step::Assessment, context::PSCOPFContext)
    println("Assessment à l'échéance ", get_current_ech(context))
    return #result
end
function update!(context::PSCOPFContext, result)
    #rien à mettre à jour
end

struct EnterFO <: AbstractRunnable
end
function run(step::EnterFO, context::PSCOPFContext)
    println("-----Entrée dans la fenêtre opérationnelle-----")
    return #result
end
function update!(context::PSCOPFContext, result)
    #rien à mettre à jour
end
