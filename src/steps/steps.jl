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
####       COMMON
################################################################################

function init_firmness(runnable::AbstractRunnable,
                    ech::Dates.DateTime, next_ech::Union{Nothing,Dates.DateTime},
                    TS::Vector{Dates.DateTime}, context::AbstractContext)
    firmness = Firmness()
    network = get_network(context)
    for generator in Networks.get_generators(network)
        #FIXME : check if generator is limitable and do something else!

        dmo = Networks.get_dmo(generator)
        dp = Networks.get_dp(generator)
        gen_id = Networks.get_id(generator)

        for ts in TS
            #commitment
            if ts - dmo < ech
                set_commitment_firmness!(firmness, gen_id, ts, DECIDED)
            elseif ( isnothing(next_ech) || (ts - dmo < next_ech) )
                set_commitment_firmness!(firmness, gen_id, ts, TO_DECIDE)
            else
                set_commitment_firmness!(firmness, gen_id, ts, FREE)
            end

            #power level
            if ts - dp < ech
                set_commitment_firmness!(firmness, gen_id, ts, DECIDED)
            elseif ( isnothing(next_ech) || (ts - dp < next_ech) )
                set_commitment_firmness!(firmness, gen_id, ts, TO_DECIDE)
            else
                set_commitment_firmness!(firmness, gen_id, ts, FREE)
            end
        end
    end

    println("fermeté des décision : ", firmness)
    return firmness
end

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
    println("\tJe me référencie au précédent planning du marché pour les arrets/démarrage et l'estimation des couts : ", safeget_last_market_schedule(context))
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage : ", safeget_last_tso_schedule(context))
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
    println("\tJe me référencie au précédent planning du marché pour les arrets/démarrage et l'estimation des couts : ", safeget_last_market_schedule(context))
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage : ", safeget_last_tso_schedule(context))
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
    println("\tJe me référencie au planning du marché du début de la FO pour les arrets/démarrage et l'estimation des couts : ", safeget_last_market_schedule(context))
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage : ", safeget_last_tso_schedule(context))
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
    println("\tJe mets à jour le planning tso: ", tso_schedule,
            " en me basant sur les résultats d'optimisation.")
    println("\tet je ne touche pas au planning du marché")
end
function update_limitations!(limitations, ech, result, firmness,
                            context::AbstractContext, runnable::AbstractTSO)
    println("\tJe mets à jour les limitations à prendre en compte par le marché")
end
function update_impositions!(impositions, ech, result, firmness,
                            context::AbstractContext, runnable::AbstractTSO)
    println("\tJe mets à jour les impositions à prendre en compte par le marché")
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
    println("\tJe me base sur le précédent planning du marché pour les arrets/démarrage des unités : ", safeget_last_market_schedule(context))
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
    println("\tJe me base sur le précédent planning du marché pour les arrets/démarrage des unités : ", safeget_last_market_schedule(context))
    println("\tJe ne regarde pas le planning du TSO.")
    println("\tC'est le dernier lancement du marché => je prends des décision fermes.")
    return #result
end

"""
utilisé pour les modes 2 et 3
Dans le mode 2 : je considère le planning du TSO
Dans le mode 3 : je considère le planning du marché
"""
struct BalanceMarket <: AbstractMarket
end
function run(runnable::BalanceMarket, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("\tJe me base sur le dernier planning disponible (marché ou TSO) pour les arrets/démarrage des unités") #besoin de récupérer le dernier planning
    println("\tJe ne regarde pas le planning du TSO.")
    println("\tC'est le dernier lancement du marché => je prends des décision fermes.")
    return #result
end

#### Market COMMON :
function update_market_schedule!(market_schedule::Schedule, ech, result, firmness,
                                context::AbstractContext, runnable::AbstractMarket)
    println("\tJe mets à jour le planning du marché: ", market_schedule,
            " en me basant sur les résultats d'optimisation.",
            " et je ne touche pas au planning du TSO")
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

