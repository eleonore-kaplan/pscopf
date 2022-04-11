using .Networks

using Dates
using JuMP
using Printf

@with_kw mutable struct EnergyMarket <: AbstractMarket
    configs = EnergyMarketConfigs()
end

@with_kw mutable struct BalanceMarket <: AbstractMarket
    configs = EnergyMarketConfigs(problem_name = "BalanceMarket",
                                CONSIDER_TSOACTIONS_LIMITATIONS=true,
                                CONSIDER_TSOACTIONS_IMPOSITIONS=true,
                                CONSIDER_TSOACTIONS_COMMITMENTS=true,
                                REF_SCHEDULE_TYPE=PSCOPF.TSO())
end

function run(runnable::Union{EnergyMarket,BalanceMarket},
            ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime},
            context::AbstractContext)
    fo_start_time = TS[1] - get_fo_length(get_management_mode(context))
    if fo_start_time <= ech
        msg = @sprintf("invalid step at ech=%s : step needs to be launched before FO start (ie %s)", ech, fo_start_time)
        throw( error(msg) )
    end

    problem_name_l = @sprintf("energy_market_%s", ech)

    tso_actions = filter_tso_actions(get_tso_actions(context),
                                    keep_limitations=runnable.configs.CONSIDER_TSOACTIONS_LIMITATIONS,
                                    keep_impositions=runnable.configs.CONSIDER_TSOACTIONS_IMPOSITIONS,
                                    keep_commitments=runnable.configs.CONSIDER_TSOACTIONS_COMMITMENTS)
    gratis_starts = Set{Tuple{String,Dates.DateTime}}()
    if runnable.configs.CONSIDER_GRATIS_STARTS
        gratis_starts = get_starts(tso_actions, get_generators_initial_state(context))
    end

    runnable.configs.out_path = context.out_dir
    runnable.configs.problem_name = problem_name_l

    return energy_market(get_network(context),
                        TS,
                        get_generators_initial_state(context),
                        get_scenarios(context, ech),
                        get_uncertainties(context, ech),
                        firmness,
                        get_market_schedule(context),
                        get_tso_schedule(context),
                        tso_actions,
                        gratis_starts,
                        runnable.configs
                        )
end

function update_market_schedule!(context::AbstractContext, ech,
                                result::EnergyMarketModel,
                                firmness,
                                runnable::Union{EnergyMarket,BalanceMarket})
    market_schedule = get_market_schedule(context)
    market_schedule.decider_type = DeciderType(runnable)
    market_schedule.decision_time = ech

    # Production level
    for ((gen_id, ts, s), p_injected_var) in result.limitable_model.p_injected
        set_prod_value!(market_schedule, gen_id, ts, s, value(p_injected_var))
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

    # Commitment
    for ((gen_id, ts, s), b_on_var) in result.imposable_model.b_on
        gen_state_value = parse(GeneratorState, value(b_on_var))
        if get_commitment_firmness(firmness, gen_id, ts) == FREE
            set_commitment_value!(market_schedule, gen_id, ts, s, gen_state_value)
        elseif get_commitment_firmness(firmness, gen_id, ts) in [TO_DECIDE, DECIDED]
            set_commitment_definitive_value!(market_schedule, gen_id, ts, gen_state_value)
        end
    end

    # Capping
    update_schedule_capping!(market_schedule, context, ech, result.limitable_model)

    # cut_conso (load-shedding)
    update_schedule_cut_conso!(market_schedule, context, ech, result.slack_model)

    return market_schedule
end

