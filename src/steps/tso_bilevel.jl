using .Networks

using Dates
using JuMP
using Printf
using Parameters

@with_kw struct TSOBilevel <: AbstractTSO
    configs::TSOBilevelConfigs = TSOBilevelConfigs()
end

function run(runnable::TSOBilevel, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    problem_name_l = @sprintf("tso_bilevel_%s", ech)

    tso_starts = get_starts(get_tso_schedule(context), get_generators_initial_state(context))
    market_starts = get_starts(get_market_schedule(context), get_generators_initial_state(context))
    gratis_starts = union(tso_starts, market_starts)

    runnable.configs.out_path = context.out_dir
    runnable.configs.problem_name = problem_name_l

    return tso_bilevel(get_network(context),
                    TS,
                    get_generators_initial_state(context),
                    get_scenarios(context, ech),
                    get_uncertainties(context, ech),
                    firmness,
                    get_market_schedule(context),
                    get_tso_schedule(context),
                    get_tso_actions(context),
                    gratis_starts,
                    runnable.configs
                    )
end

function update_tso_schedule!(context::AbstractContext, ech, result, firmness,
                            runnable::TSOBilevel)
    error("TODO")
end

function update_schedule_capping!(tso_schedule, context, ech,
                                    limitable_model::TSOBilevelTSOLimitableModel)
    reset_capping!(tso_schedule)
    error("TODO")
end

function update_schedule_cut_conso!(tso_schedule, context, ech, slack_model::TSOBilevelTSOSlackModel)
    reset_cut_conso_by_bus!(tso_schedule)
    error("TODO")
end


function update_tso_actions!(context::AbstractContext, ech, result, firmness,
                            ::TSOBilevel)
    error("TODO")
end
