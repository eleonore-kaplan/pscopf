using .Networks

using Dates

################################################################################
####       TSO
################################################################################

"""
utilisé pour le mode 3:
Prend des décisions fermes vu que c'est la dernière execution du TSO
Décide de la reserve
"""
struct TSOAtFOBiLevel <: AbstractTSO
end
function run(runnable::TSOAtFOBiLevel, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("\tJe me référencie au précédent planning du marché pour les arrets/démarrage et l'estimation des couts : ",
            get_market_schedule(context).decider_type, ",", get_market_schedule(context).decision_time)
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage : ",
            get_tso_schedule(context).decider_type, ",", get_tso_schedule(context).decision_time)
    println("\tC'est le dernier lancement du tso => le planning TSO que je fournie doit etre ferme")
    return #result
end

#### TSO COMMON :
function update_tso_schedule!(context::AbstractContext, ech, result, firmness,
                            runnable::AbstractTSO)
    tso_schedule = get_tso_schedule(context)
    tso_schedule.decider_type = DeciderType(runnable)
    tso_schedule.decision_time = ech
    println("\tJe mets à jour le planning tso: ",
            tso_schedule.decider_type, ",",tso_schedule.decision_time,
            " en me basant sur les résultats d'optimisation.")
    println("\tet je ne touche pas au planning du marché")
end
function update_tso_actions!(context::AbstractContext, ech, result, firmness,
                            runnable::AbstractTSO)
    println("\tJe mets à jour les actions TSO (limitations, impositions) à prendre en compte par le marché")
end

################################################################################
####       MARKET
################################################################################

# EnergyMarket : c.f. energy_market.jl
# EnergyMarketAtFO : c.f. energy_market_at_fo.jl


"""
utilisé pour les modes 2
et 3 ?
"""
struct BalanceMarket <: AbstractMarket
end
function run(runnable::BalanceMarket, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("\tJe me base sur le planning marché (potentiellemnt maj par le TSO) pour les arrets/démarrage des unités : ",
            get_market_schedule(context).decider_type, ",",get_market_schedule(context).decision_time
            )
    println("\tJe ne regarde pas le planning du TSO.")
    println("\tC'est le dernier lancement du marché => je prends des décision fermes.")
    return #result
end
function update_market_schedule!(context::AbstractContext, ech, result, firmness,
                                runnable::BalanceMarket)
    market_schedule = get_market_schedule(context)
    market_schedule.decider_type = DeciderType(runnable)
    market_schedule.decision_time = ech
    println("\tJe mets à jour le planning du marché: ",
            market_schedule.decider_type, ",",market_schedule.decision_time,
            " en me basant sur les résultats d'optimisation.",
            " et je ne touche pas au planning du TSO")
end


################################################################################
####       Firmness
################################################################################

function compute_firmness(runnable::AbstractRunnable,
                    ech::Dates.DateTime, next_ech::Union{Nothing,Dates.DateTime},
                    TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("Initialisation de la fermeté des décisions.")
    generators = collect(Networks.get_generators(get_network(context)))
    return compute_firmness(ech, next_ech, TS, generators)
end

"""
    All decisions are Firm (DECIDED or TO_DECIDE)
"""
function compute_firmness(runnable::Union{EnergyMarketAtFO,TSOAtFOBiLevel},
                    ech::Dates.DateTime, next_ech::Union{Nothing,Dates.DateTime},
                    TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("Initialisation de la fermeté des décisions : DECIDED ou TO_DECIDE")
    next_ech = nothing
    generators = collect(Networks.get_generators(get_network(context)))
    return compute_firmness(ech, next_ech, TS, generators)
end


################################################################################
####       Utils
################################################################################

struct Assessment <: AbstractRunnable
end
function run(runnable::Assessment, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    return #result
end

struct EnterFO <: AbstractRunnable
end
function run(runnable::EnterFO, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("-----Entrée dans la fenêtre opérationnelle-----")
    return #result
end

