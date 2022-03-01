using ..Networks

using JuMP
using Parameters


@with_kw struct EnergyMarketLimitableModel <: AbstractGeneratorModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #firmness_constraints
end

@with_kw struct EnergyMarketImposableModel <: AbstractGeneratorModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_start = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_on = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #commitment_constraints = Dict{Tuple{String,DateTime,String},ConstraintRef}();
    #firmness_constraints
end


@with_kw mutable struct EnergyMarketObjectiveModel <: AbstractObjectiveModel
    prop_cost = AffExpr(0)
    start_cost = AffExpr(0)

    full_obj = AffExpr(0)
end


@with_kw mutable struct EnergyMarketModel <: AbstractModelContainer
    model::Model = Model()
    limitable_model::EnergyMarketLimitableModel = EnergyMarketLimitableModel()
    imposable_model::EnergyMarketImposableModel = EnergyMarketImposableModel()
    objective_model::EnergyMarketObjectiveModel = EnergyMarketObjectiveModel()
    eod_constraint::SortedDict{Tuple{Dates.DateTime,String}, ConstraintRef} =
        SortedDict{Tuple{Dates.DateTime,String}, ConstraintRef}()
    #v_flow = Dict{Tuple{String,DateTime,String},VariableRef}()
    status::PSCOPFStatus = pscopf_UNSOLVED
end

include("energy_market_impl.jl")

struct EnergyMarket <: AbstractMarket
end

function run(runnable::EnergyMarket,
            ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime},
            context::AbstractContext)
    fo_start_time = TS[1] - get_fo_length(get_management_mode(context))
    if fo_start_time <= ech
        msg = @sprintf("invalid step at ech=%s : EnergyMarket needs to be launched before FO start (ie %s)", ech, fo_start_time)
        throw( error(msg) )
    end

    problem_name_l = @sprintf("energy_market_%s", ech)
    println("\tJe me base sur le précédent planning du marché pour les arrets/démarrage des unités : ",
     get_market_schedule(context).type, ",",get_market_schedule(context).decision_time)
    println("\tJe regarde le planning du TSO et je ne paie pas les couts de démarrage des unités déjà démarrées de façon définitive.")

    gratis_starts = definitive_starts(get_tso_schedule(context), get_generators_initial_state(context))

    return energy_market(get_network(context),
                        TS,
                        get_generators_initial_state(context),
                        get_scenarios(context, ech),
                        get_uncertainties(context, ech),
                        firmness,
                        get_market_schedule(context),
                        gratis_starts,
                        out_path=context.out_dir,
                        problem_name=problem_name_l,
                        )
end

function update_market_schedule!(market_schedule::Schedule, ech,
                                result::EnergyMarketModel,
                                firmness,
                                context::AbstractContext, runnable::EnergyMarket)

    println("\tJe mets à jour le planning du marché: ",
            market_schedule.type, ",",market_schedule.decision_time,
            " en me basant sur les résultats d'optimisation.",
            " et je ne touche pas au planning du TSO")

    market_schedule.decision_time = ech


    for ((gen_id, ts, s), p_injected_var) in result.limitable_model.p_injected
        if get_power_level_firmness(firmness, gen_id, ts) == FREE
            set_prod_value!(market_schedule, gen_id, ts, s, value(p_injected_var))
        elseif get_power_level_firmness(firmness, gen_id, ts) == TO_DECIDE
            set_prod_definitive_value!(market_schedule, gen_id, ts, value(p_injected_var))
        elseif get_power_level_firmness(firmness, gen_id, ts) == DECIDED
            @assert( value(p_injected_var) == get_prod_value(market_schedule, gen_id, ts) )
        end
    end
    for ((gen_id, ts, s), p_injected_var) in result.imposable_model.p_injected
        if get_power_level_firmness(firmness, gen_id, ts) == FREE
            set_prod_value!(market_schedule, gen_id, ts, s, value(p_injected_var))
        elseif get_power_level_firmness(firmness, gen_id, ts) == TO_DECIDE
            set_prod_definitive_value!(market_schedule, gen_id, ts, value(p_injected_var))
        elseif get_power_level_firmness(firmness, gen_id, ts) == DECIDED
            @assert( value(p_injected_var) ≈ get_prod_value(market_schedule, gen_id, ts) )
        end
    end

    for ((gen_id, ts, s), b_on_var) in result.imposable_model.b_on
        gen_state_value = parse(GeneratorState, value(b_on_var))
        if get_commitment_firmness(firmness, gen_id, ts) == FREE
            set_commitment_value!(market_schedule, gen_id, ts, s, gen_state_value)
        elseif get_commitment_firmness(firmness, gen_id, ts) == TO_DECIDE
            set_commitment_definitive_value!(market_schedule, gen_id, ts, gen_state_value)
        elseif get_commitment_firmness(firmness, gen_id, ts) == DECIDED
            @assert( gen_state_value == get_commitment_value(market_schedule, gen_id, ts) )
        end
    end

    return market_schedule
end

