using ..Networks

using Dates

struct OptimResult end

struct TSO <: DeciderType end
struct Market <: DeciderType end
struct Utilitary <: DeciderType end
DeciderType(::Type{<:AbstractRunnable}) = Utilitary()
DeciderType(::Type{<:AbstractTSO}) = TSO()
DeciderType(::Type{<:AbstractMarket}) = Market()

is_tso(x::T) where {T} = is_tso(DeciderType(T))
is_tso(::DeciderType) = false
is_tso(::TSO) = true

is_market(x::T) where {T} = is_market(DeciderType(T))
is_market(::DeciderType) = false
is_market(::Market) = true

################################################################################
####       TSO
################################################################################

"""
utilisé dans les trois modes
Prend des décisions en se référençant à une situation équilibrée par le marché
N'utilise pas la reserve ?
"""
struct TSOOutFO <: AbstractTSO
end
function run(runnable::TSOOutFO, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("\tJe me référencie au précédent planning du marché pour les arrets/démarrage et l'estimation des couts : ",
            safeget_last_market_schedule(context).type, ",", safeget_last_market_schedule(context).decision_time)
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage : ",
            safeget_last_tso_schedule(context).type, ",", safeget_last_tso_schedule(context).decision_time)
    return #result
end

"""
utilisé pour le mode 3:
Prend des décisions fermes vu que c'est la dernière execution du TSO
Décide de la reserve
"""
struct TSOAtFOBiLevel <: AbstractTSO
end
function run(runnable::TSOAtFOBiLevel, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("\tJe me référencie au précédent planning du marché pour les arrets/démarrage et l'estimation des couts : ",
            safeget_last_market_schedule(context).type, ",", safeget_last_market_schedule(context).decision_time)
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage : ",
            safeget_last_tso_schedule(context).type, ",", safeget_last_tso_schedule(context).decision_time)
    println("\tC'est le dernier lancement du tso => le planning TSO que je fournie doit etre ferme")
    return #result
end

"""
utilisé pour le mode 1:
Prend des incertitudes non équilibrées (mode 1 => plus de marché dans la FO)
Décide de la reserve
"""
struct TSOInFO <: AbstractTSO
end
function run(runnable::TSOInFO, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("\tJe me référencie au planning du marché du début de la FO pour les arrets/démarrage et l'estimation des couts : ",
            safeget_last_market_schedule(context).type, ",",safeget_last_market_schedule(context).decision_time)
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage : ",
            safeget_last_tso_schedule(context).type, ",", safeget_last_tso_schedule(context).decision_time)
    return #result
end

"""
utilisé pour le mode 2:
Prend des incertitudes pas forcément équilibrées
Décide de la reserve
Simule un marché d'équilibrage
"""
struct TSOBiLevel <: AbstractTSO
end
function run(runnable::TSOBiLevel, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("\tJe simule un marché d'équilibrage pour le pas suivant")
    println("\tJe me référencie au planning du marché du début de la FO pour les arrets/démarrage et l'estimation des couts ?")
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage ?")
    return #result
end


#### TSO COMMON :
function update_tso_schedule!(tso_schedule::Schedule, ech, result, firmness,
                            context::AbstractContext, runnable::AbstractTSO)
    println("\tJe mets à jour le planning tso: ",
            tso_schedule.type, ",",tso_schedule.decision_time,
            " en me basant sur les résultats d'optimisation.")
    println("\tet je ne touche pas au planning du marché")
end
function update_tso_actions!(tso_actions, ech, result, firmness,
                            context::AbstractContext, runnable::AbstractTSO)
    println("\tJe mets à jour les actions TSO (limitations, impositions) à prendre en compte par le marché")
end

################################################################################
####       MARKET
################################################################################

"""
utilisé pour les trois modes :
Ne regarde pas le planning du TSO
"""
struct EnergyMarket <: AbstractMarket
end
function run(runnable::EnergyMarket, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("\tJe me base sur le précédent planning du marché pour les arrets/démarrage des unités : ",
            safeget_last_market_schedule(context).type, ",",safeget_last_market_schedule(context).decision_time)
    println("\tJe ne regarde pas le planning du TSO.")
    return #result
end

"""
utilisé pour le mode 1:
Dans le mode 1, le marché ne s'écecutera plus dans la FO => besoin de décisions fermes
"""
struct EnergyMarketAtFO <: AbstractMarket
end
function run(runnable::EnergyMarketAtFO, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("\tJe me base sur le précédent planning du marché pour les arrets/démarrage des unités : ",
            safeget_last_market_schedule(context).type, ",",safeget_last_market_schedule(context).decision_time)
    println("\tJe ne regarde pas le planning du TSO.")
    println("\tC'est le dernier lancement du marché => je prends des décision fermes.")
    return #result
end

"""
utilisé pour les modes 2
et 3 ?
"""
struct BalanceMarket <: AbstractMarket
end
function run(runnable::BalanceMarket, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("\tJe me base sur le planning marché (potentiellemnt maj par le TSO) pour les arrets/démarrage des unités : ",
            safeget_last_market_schedule(context).type, ",",safeget_last_market_schedule(context).decision_time
            ) #besoin de récupérer le dernier planning
    println("\tJe ne regarde pas le planning du TSO.")
    println("\tC'est le dernier lancement du marché => je prends des décision fermes.")
    return #result
end

#### Market COMMON :
function update_market_schedule!(market_schedule::Schedule, ech, result, firmness,
                                context::AbstractContext, runnable::AbstractMarket)
    println("\tJe mets à jour le planning du marché: ",
            market_schedule.type, ",",market_schedule.decision_time,
            " en me basant sur les résultats d'optimisation.",
            " et je ne touche pas au planning du TSO")
end


################################################################################
####       Firmness
################################################################################

"""
    Determines whether a decision should be :
    - already decided : DECIDED
    - to decide firmly (setting a common value for all scenarios) : TO_DECIDE
    - to decide freely (possibly setting different values for different scenarios): FREE
    The decision is based on the characteristic time period `delta` (delta can represent the DMO or DP)
"""
function compute_firmness(ech::Dates.DateTime, next_ech::Union{Nothing,Dates.DateTime},
                        ts::Dates.DateTime, delta::Dates.Period)
    if ( !isnothing(next_ech) && (next_ech < ech) )
        throw( error("next_ech (", next_ech, ") must be later than ech (", ech,").") )
    end

    final_decision_time = ts - delta

    if final_decision_time < ech
        return DECIDED
    elseif ( isnothing(next_ech) || (final_decision_time < next_ech) )
        return TO_DECIDE
    else
        return FREE
    end
end

function init_firmness(runnable::AbstractRunnable,
                    ech::Dates.DateTime, next_ech::Union{Nothing,Dates.DateTime},
                    TS::Vector{Dates.DateTime}, context::AbstractContext)
    firmness = Firmness()
    network = get_network(context)
    for generator in Networks.get_generators(network)
        gen_id = Networks.get_id(generator)
        dmo = Networks.get_dmo(generator)
        dp = Networks.get_dp(generator)

        for ts in TS
            #commitment
            commitment_firmness = compute_firmness(ech, next_ech, ts, dmo)
            set_commitment_firmness!(firmness, gen_id, ts, commitment_firmness)

            #power level
            power_level_firmness = compute_firmness(ech, next_ech, ts, dp)
            set_power_level_firmness!(firmness, gen_id, ts, power_level_firmness)
        end
    end

    println("Initialisation de la fermeté des décisions.")
    return firmness
end


#TODO
# """
#     All decisions are Firm (to_decide or decided)
# """
# function init_firmness(runnable::Union{EnergyMarketAtFO,TSOAtFOBiLevel},
#                     ech::Dates.DateTime, next_ech::Union{Nothing,Dates.DateTime},
#                     TS::Vector{Dates.DateTime}, context::AbstractContext)
#     next_ech = nothing
# end


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

