using .Networks

using Dates
using JuMP
using Statistics
using Printf

struct EnergyMarketAtFO <: AbstractMarket
end

SCENARIOS_DELIMITER = "_+_"

function aggregate_scenario_name(scenarios::Vector{String})
    return join(scenarios, SCENARIOS_DELIMITER)
end
function aggregate_scenario_name(context::AbstractContext, ech::Dates.DateTime)
    scenarios = get_scenarios(context, ech)
    return aggregate_scenario_name(scenarios)
end

function aggregate_scenarios(context::AbstractContext, ech::Dates.DateTime)
    agg_scenario_name = aggregate_scenario_name(context, ech)

    agg_uncertainties_at_ech = UncertaintiesAtEch()
    uncertainties_at_ech = get_uncertainties(context, ech)
    for (injection_name, _) in uncertainties_at_ech
        for (ts, by_scenario_injections) in get_uncertainties(uncertainties_at_ech, injection_name)
            values = []
            for (_, val) in by_scenario_injections
                push!(values, val)
            end
            value_l = mean(values)
            PSCOPF.add_uncertainty!(agg_uncertainties_at_ech, injection_name, ts, agg_scenario_name, value_l)
        end
    end

    return agg_scenario_name, agg_uncertainties_at_ech
end

function run(runnable::EnergyMarketAtFO,
            ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime},
            context::AbstractContext)
    fo_start_time = TS[1] - get_fo_length(get_management_mode(context))
    if fo_start_time != ech
        msg = @sprintf("invalid step at ech=%s : EnergyMarketAtFO needs to be launched at FO start (ie %s)", ech, fo_start_time)
        throw( error(msg) )
    end

    problem_name_l = @sprintf("energy_market_at_FO_%s", ech)

    #TODO create a TSO action for commitment, and base decisions on that imposition
    tso_starts = definitive_starts(get_tso_schedule(context), get_generators_initial_state(context))
    market_starts = definitive_starts(get_market_schedule(context), get_generators_initial_state(context))
    gratis_starts = union(tso_starts, market_starts)

    agg_scenario_name, agg_uncertainties = aggregate_scenarios(context, ech)

    @assert(length(get_scenarios(agg_uncertainties)) == 1)
    @assert check_uncertainties(Uncertainties(ech=>agg_uncertainties), get_network(context))
    @assert check_uncertainties_contain_ts(Uncertainties(ech=>agg_uncertainties), get_target_timepoints(context))

    return energy_market(get_network(context),
                        TS,
                        get_generators_initial_state(context),
                        [agg_scenario_name],
                        agg_uncertainties,
                        firmness,
                        get_market_schedule(context), #this uses original scenario names
                        gratis_starts,
                        out_path=context.out_dir,
                        problem_name=problem_name_l,
                        )
end

function update_market_schedule!(context::AbstractContext, ech,
                                result::EnergyMarketModel,
                                firmness,
                                runnable::EnergyMarketAtFO)
    market_schedule = get_market_schedule(context)

    market_schedule.decider_type = DeciderType(runnable)
    market_schedule.decision_time = ech


    for ((gen_id, ts, s), p_injected_var) in result.limitable_model.p_injected
        for scenario in split(s, SCENARIOS_DELIMITER)
            if get_power_level_firmness(firmness, gen_id, ts) == FREE
                set_prod_value!(market_schedule, gen_id, ts, scenario, value(p_injected_var))
            elseif get_power_level_firmness(firmness, gen_id, ts) == TO_DECIDE
                set_prod_definitive_value!(market_schedule, gen_id, ts, value(p_injected_var))
            elseif get_power_level_firmness(firmness, gen_id, ts) == DECIDED
                @assert( value(p_injected_var) == get_prod_value(market_schedule, gen_id, ts) )
            end
        end
    end
    for ((gen_id, ts, s), p_injected_var) in result.imposable_model.p_injected
        for scenario in split(s, SCENARIOS_DELIMITER)
            if get_power_level_firmness(firmness, gen_id, ts) == FREE
                set_prod_value!(market_schedule, gen_id, ts, scenario, value(p_injected_var))
            elseif get_power_level_firmness(firmness, gen_id, ts) == TO_DECIDE
                set_prod_definitive_value!(market_schedule, gen_id, ts, value(p_injected_var))
            elseif get_power_level_firmness(firmness, gen_id, ts) == DECIDED
                @assert( value(p_injected_var) ≈ get_prod_value(market_schedule, gen_id, ts) )
            end
        end
    end

    for ((gen_id, ts, s), b_on_var) in result.imposable_model.b_on
        gen_state_value = parse(GeneratorState, value(b_on_var))
        for scenario in split(s, SCENARIOS_DELIMITER)
            if get_commitment_firmness(firmness, gen_id, ts) == FREE
                set_commitment_value!(market_schedule, gen_id, ts, scenario, gen_state_value)
            elseif get_commitment_firmness(firmness, gen_id, ts) == TO_DECIDE
                set_commitment_definitive_value!(market_schedule, gen_id, ts, gen_state_value)
            elseif get_commitment_firmness(firmness, gen_id, ts) == DECIDED
                @assert( gen_state_value == get_commitment_value(market_schedule, gen_id, ts) )
            end
        end
    end

    return market_schedule
end
