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

struct TSOMode1 <: AbstractTSO
end
function run(step::TSOMode1, context::PSCOPFContext)
    println("TSOMode1 à l'échéance ", get_current_ech(context))
    println("\tJe me référencie au précédent planning du marché pour les arrets/démarrage et l'estimation des couts : ", get_last_market_planning(context))
    println("\tJe me référencie au précédent planning du TSO pour les arrets/démarrage : ", get_last_tso_planning(context))
    #D'ou la nécessité du bloc orange qui va fournir un état réel du réseau sur lequel se basera le TSO (mais pas le marché hors fenêtre opérationnelle)
    return #result
end
function update!(context::PSCOPFContext, result)
    println("\tJe mets à jour le planning tso: ", get_last_tso_planning(context),
            " en me basant sur les résultats d'optimisation.", #step.result
            " et je ne touche pas au planning du marché")
end

################################################################################
####       MARKET
################################################################################
abstract type  AbstractMarket <: AbstractRunnable  end

struct MarketMode1OutFO <: AbstractMarket
end
function run(step::MarketMode1OutFO, context::PSCOPFContext)
    println("MarketMode1OutFO à l'échéance ", get_current_ech(context))
    println("\tJe me base sur le précédent planning du marché pour les arrets/démarrage des unités : ", get_last_market_planning(context))
    println("\tJe ne regarde pas le planning du TSO.")
    return #result
end
function update!(context::PSCOPFContext, result)
    println("\tJe mets à jour ce même planning marché: ", get_last_market_planning(context),
            " en me basant sur les résultats d'optimisation.", #step.result
            " et je ne touche pas au planning TSO.")
end

struct MarketMode1InFO <: AbstractMarket
end
function run(step::MarketMode1InFO, context::PSCOPFContext)
    println("MarketMode1InFO à l'échéance ", get_current_ech(context))
    println("\tJe me base sur le précédent planning du TSO et non pas du marché pour les arrets/démarrage des unités : ", get_last_tso_planning(context))
    return #result
end
function update!(context::PSCOPFContext, result)
    println("\tJe mets à jour le planning du marché: ", get_last_market_planning(context),
            " en me basant sur les résultats d'optimisation.", #step.result
            " et je ne touche pas au planning du TSO (ou si?).")
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
