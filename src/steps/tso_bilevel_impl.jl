using .Networks

using JuMP
using Dates
using DataStructures
using Printf
using Parameters

@with_kw mutable struct TSOBilevelConfigs
    cut_conso_penalty::Float64 = 1e7
    capping_cost::Float64 = 1.
    out_path::Union{Nothing,String} = nothing
    problem_name::String = "TSOBilevel"
    LINK_SCENARIOS_LIMIT::Bool = false
    LINK_SCENARIOS_IMPOSABLE_LEVEL::Bool = false
    LINK_SCENARIOS_IMPOSABLE_ON::Bool = false
end

##########################################################
#        upper problem : TSO
##########################################################

@with_kw struct TSOBilevelTSOLimitableModel <: AbstractLimitableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},BilevelJuMP.BilevelVariableRef}();
    #gen,ts,s
    p_limit = SortedDict{Tuple{String,DateTime,String},BilevelJuMP.BilevelVariableRef}();
    #gen,ts,s
    b_is_limited = SortedDict{Tuple{String,DateTime,String},BilevelJuMP.BilevelVariableRef}();
    #gen,ts,s
    p_limit_x_is_limited = SortedDict{Tuple{String,DateTime,String},BilevelJuMP.BilevelVariableRef}();
    #gen,ts,s
    p_capping = SortedDict{Tuple{String,DateTime,String},BilevelJuMP.BilevelVariableRef}();
    #ts,s
    p_capping_min = SortedDict{Tuple{DateTime,String},BilevelJuMP.BilevelVariableRef}();
end

@with_kw struct TSOBilevelTSOImposableModel <: AbstractImposableModel
    #gen,ts,s
    p_tso_min = SortedDict{Tuple{String,DateTime,String},BilevelJuMP.BilevelVariableRef}();
    #gen,ts,s
    p_tso_max = SortedDict{Tuple{String,DateTime,String},BilevelJuMP.BilevelVariableRef}();
    #gen,ts,s
    b_start = SortedDict{Tuple{String,DateTime,String},BilevelJuMP.BilevelVariableRef}();
    #gen,ts,s
    b_on = SortedDict{Tuple{String,DateTime,String},BilevelJuMP.BilevelVariableRef}();
end

@with_kw struct TSOBilevelTSOSlackModel <: AbstractSlackModel
    #bus,ts,s #Loss of Load
    p_cut_conso = SortedDict{Tuple{String,DateTime,String},BilevelJuMP.BilevelVariableRef}();
    #ts,s
    p_cut_conso_min = SortedDict{Tuple{DateTime,String},BilevelJuMP.BilevelVariableRef}();
end

@with_kw mutable struct TSOBilevelTSOObjectiveModel <: AbstractObjectiveModel
    limitable_cost = GenericAffExpr{Float64, BilevelJuMP.BilevelVariableRef}()
    imposable_cost = GenericAffExpr{Float64, BilevelJuMP.BilevelVariableRef}()

    penalty = GenericAffExpr{Float64, BilevelJuMP.BilevelVariableRef}()

    full_obj = GenericAffExpr{Float64, BilevelJuMP.BilevelVariableRef}()
end

##########################################################
#        lower problem : Market
##########################################################
@with_kw struct TSOBilevelMarketLimitableModel <: AbstractLimitableModel
    #ts,s #FIXME not sure if this should be a lower or an upper variable
    p_injected = SortedDict{Tuple{DateTime,String},BilevelJuMP.BilevelVariableRef}();
    #ts,s
    p_capping = SortedDict{Tuple{DateTime,String},BilevelJuMP.BilevelVariableRef}();
end

@with_kw struct TSOBilevelMarketImposableModel <: AbstractImposableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},BilevelJuMP.BilevelVariableRef}();
end

@with_kw struct TSOBilevelMarketSlackModel <: AbstractSlackModel
    #ts,s
    p_cut_conso = SortedDict{Tuple{DateTime,String},BilevelJuMP.BilevelVariableRef}();
end

@with_kw mutable struct TSOBilevelMarketObjectiveModel <: AbstractObjectiveModel
    limitable_cost = GenericAffExpr{Float64, BilevelJuMP.BilevelVariableRef}()
    imposable_cost = GenericAffExpr{Float64, BilevelJuMP.BilevelVariableRef}()

    penalty = GenericAffExpr{Float64, BilevelJuMP.BilevelVariableRef}()

    full_obj = GenericAffExpr{Float64, BilevelJuMP.BilevelVariableRef}()
end

##########################################################
#        TSOBilevel Model
##########################################################

@with_kw struct TSOBilevelTSOModelContainer <: AbstractModelContainer
    model::BilevelJuMP.UpperModel
    limitable_model::TSOBilevelTSOLimitableModel = TSOBilevelTSOLimitableModel()
    imposable_model::TSOBilevelTSOImposableModel = TSOBilevelTSOImposableModel()
    slack_model::TSOBilevelTSOSlackModel = TSOBilevelTSOSlackModel()
    objective_model::TSOBilevelTSOObjectiveModel = TSOBilevelTSOObjectiveModel()
end
@with_kw struct TSOBilevelMarketModelContainer <: AbstractModelContainer
    model::BilevelJuMP.LowerModel
    limitable_model::TSOBilevelMarketLimitableModel = TSOBilevelMarketLimitableModel()
    imposable_model::TSOBilevelMarketImposableModel = TSOBilevelMarketImposableModel()
    slack_model::TSOBilevelMarketSlackModel = TSOBilevelMarketSlackModel()
    objective_model::TSOBilevelMarketObjectiveModel = TSOBilevelMarketObjectiveModel()
end
TSOBilevelModel = BilevelModelContainer{TSOBilevelTSOModelContainer, TSOBilevelMarketModelContainer}
function BilevelModelContainer{TSOBilevelTSOModelContainer,TSOBilevelMarketModelContainer}()
    bilevel_model = BilevelModel(OPTIMIZER)
    upper = TSOBilevelTSOModelContainer(model=Upper(bilevel_model))
    lower = TSOBilevelMarketModelContainer(model=Lower(bilevel_model))
    return BilevelModelContainer(bilevel_model, upper, lower)
end


function has_positive_slack(model_container::TSOBilevelModel)::Bool
    return ( has_positive_value(model_container.upper.slack_model.p_cut_conso)
            || has_positive_value(model_container.lower.slack_model.p_cut_conso))
end


##########################################################
#        upper problem : TSO functions : TSOBilevelTSOModelContainer
##########################################################
function create_tso_vars!( model_container::TSOBilevelTSOModelContainer,
                            network::Networks.Network,
                            target_timepoints::Vector{Dates.DateTime},
                            generators_initial_state::SortedDict{String,GeneratorState},
                            scenarios::Vector{String},
                            uncertainties_at_ech::UncertaintiesAtEch,
                            firmness::Firmness,
                            preceding_tso_schedule::Schedule,
                            preceding_tso_actions::TSOActions,
                            configs::TSOBilevelConfigs)
    add_limitables!(model_container,
                            network, target_timepoints, scenarios,
                            uncertainties_at_ech, firmness,
                            configs.LINK_SCENARIOS_LIMIT)
    # add_imposables!(model_container,
    #                         network, target_timepoints, scenarios,
    #                         generators_initial_state,
    #                         firmness,
    #                         preceding_tso_schedule,
    #                         preceding_tso_actions,
    #                         configs.LINK_SCENARIOS_IMPOSABLE_ON, configs.LINK_SCENARIOS_IMPOSABLE_LEVEL)
    add_slacks!(model_container, network, target_timepoints, scenarios, uncertainties_at_ech)
end

function add_limitable!(limitable_model::TSOBilevelTSOLimitableModel, model::AbstractModel,
                            generator::Networks.Generator,
                            target_timepoints::Vector{Dates.DateTime},
                            scenarios::Vector{String},
                            inject_uncertainties::InjectionUncertainties,
                            power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness},#by ts
                            always_link_scenarios_limit
                        )
    gen_id = Networks.get_id(generator)
    gen_pmax = Networks.get_p_max(generator)
    for ts in target_timepoints
        for s in scenarios
            println("gen_id:",gen_id, ", ts:",ts ,", s:",s)
            p_uncert = get_uncertainties(inject_uncertainties, ts, s)
            p_enr = min(gen_pmax, p_uncert)
            p_inj_var = add_p_injected!(limitable_model, model, gen_id, ts, s, p_enr, false)
            name =  @sprintf("P_capping[%s,%s,%s]", gen_id, ts, s)
            limitable_model.p_capping[gen_id, ts, s] = @variable(model, base_name=name, lower_bound=0.)
            @constraint(model, limitable_model.p_capping[gen_id, ts, s] == p_uncert - p_inj_var )
        end
        add_p_limit!(limitable_model, model, gen_id, ts, scenarios, gen_pmax,
                inject_uncertainties,
                power_level_firmness[ts],
                always_link_scenarios_limit)
    end
    return limitable_model
end
function add_limitables!(model_container::TSOBilevelTSOModelContainer,
                            network::Networks.Network,
                            target_timepoints::Vector{Dates.DateTime},
                            scenarios::Vector{String},
                            uncertainties_at_ech::UncertaintiesAtEch,
                            firmness::Firmness,
                            always_link_scenarios_limit=false
                            )
    model = model_container.model
    limitable_model = model_container.limitable_model
    for generator in Networks.get_generators_of_type(network, Networks.LIMITABLE)
        gen_id = Networks.get_id(generator)
        inject_uncertainties = get_uncertainties(uncertainties_at_ech, gen_id)
        add_limitable!(limitable_model, model,
                        generator, target_timepoints, scenarios,
                        inject_uncertainties,
                        get_power_level_firmness(firmness, gen_id), always_link_scenarios_limit)
    end

    for ts in target_timepoints
        for s in scenarios
            enr_max = compute_prod(uncertainties_at_ech, network, ts, s)
            name =  @sprintf("P_capping_min[%s,%s]", ts, s)
            limitable_model.p_capping_min[ts, s] = @variable(model, base_name=name, lower_bound=0., upper_bound=enr_max)
        end
    end

    return model_container
end

function create_injection_bounds_vars!(imposable_model, model,
                                    gen_id, target_timepoints, scenarios, p_max,
                                    gen_power_firmness, imposition::Union{Missing, Tuple{Float64,Float64}},
                                    always_link_scenarios=false)
    for ts in target_timepoints
        for s in scenarios
            name =  @sprintf("P_tso_min[%s,%s,%s]", gen_id, ts, s)
            imposable_model.p_tso_min[gen_id, ts, s] = @variable(model, base_name=name,
                                                                lower_bound=0., upper_bound=p_max)
            name =  @sprintf("P_tso_max[%s,%s,%s]", gen_id, ts, s)
            imposable_model.p_tso_max[gen_id, ts, s] = @variable(model, base_name=name,
                                                                lower_bound=0., upper_bound=p_max)
        end

        if always_link_scenarios || (gen_power_firmness[ts] in [DECIDED, TO_DECIDE])
            link_scenarios!(model, imposable_model.p_tso_min, gen_id, ts, scenarios)
            link_scenarios!(model, imposable_model.p_tso_max, gen_id, ts, scenarios)
        end

        if !ismissing(imposition)
            min_imposition = imposition[1]
            freeze_vars!(model, imposable_model.p_tso_min, gen_id, ts, scenarios, min_imposition)
            max_imposition = imposition[2]
            freeze_vars!(model, imposable_model.p_tso_max, gen_id, ts, scenarios, max_imposition)
        end
    end
end
function create_commitment_vars!(imposable_model, model,
                                generator, target_timepoints, scenarios,
                                generator_initial_state,
                                gen_commitment_firmness,
                                generator_reference_schedule,
                                commitment_actions,
                                always_link_scenarios)
    p_tso_min = imposable_model.p_tso_min
    p_tso_max = imposable_model.p_tso_max
    b_on_vars = imposable_model.b_on
    b_start_vars = imposable_model.b_start

    gen_id = Networks.get_id(generator)
    p_max = Networks.get_p_max(generator)
    p_min = Networks.get_p_min(generator)

    for s in scenarios
        for ts in target_timepoints
            name =  @sprintf("B_on[%s,%s,%s]", gen_id, ts, s)
            b_on_vars[gen_id, ts, s] = @variable(model, base_name=name, binary=true)
            name =  @sprintf("B_start[%s,%s,%s]", gen_id, ts, s)
            b_start_vars[gen_id, ts, s] = @variable(model, base_name=name, binary=true)

            # pmin B_on < P_tso_min < P_tso_max < pmax B_on
            @constraint(model, p_min * b_on_vars[gen_id, ts, s] <= p_tso_min[gen_id, ts, s]);
            @constraint(model, p_tso_min[gen_id, ts, s] <= p_tso_max[gen_id, ts, s])
            @constraint(model, p_tso_max[gen_id, ts, s] <= p_max * b_on_vars[gen_id, ts, s])
        end
    end

    #link b_on and b_start
    add_commitment_constraints!(model,
                                b_on_vars, b_start_vars,
                                gen_id, target_timepoints, scenarios, generator_initial_state)

    #scenarios and DMO related constraints
    add_commitment_firmness_constraints!(model, generator,
                                        b_on_vars, b_start_vars,
                                        target_timepoints, scenarios,
                                        gen_commitment_firmness,
                                        generator_reference_schedule,
                                        commitment_actions,
                                        always_link_scenarios)
end
function add_imposable!(imposable_model::TSOBilevelTSOImposableModel, model::AbstractModel,
                            generator::Networks.Generator,
                            target_timepoints::Vector{Dates.DateTime},
                            scenarios::Vector{String},
                            generator_initial_state::GeneratorState,
                            commitment_firmness::Union{Missing,SortedDict{Dates.DateTime, DecisionFirmness}}, #by ts #or Missing
                            power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                            generator_reference_schedule::GeneratorSchedule,
                            preceding_tso_actions::TSOActions,
                            always_link_commitment::Bool,
                            always_link_levels::Bool)
    gen_id = Networks.get_id(generator)
    p_min = Networks.get_p_min(generator)
    p_max = Networks.get_p_max(generator)
    create_injection_bounds_vars!(imposable_model, model, gen_id, target_timepoints, scenarios, p_max,
                                power_level_firmness,
                                get_imposition(preceding_tso_actions, gen_id),
                                always_link_levels)
    if p_min > 0
        create_commitment_vars!(imposable_model, model, generator, target_timepoints, scenarios,
                                generator_initial_state,
                                commitment_firmness,
                                generator_reference_schedule,
                                get_commitment(preceding_tso_actions, gen_id),
                                always_link_commitment)
    end
end
function add_imposables!(model_container::TSOBilevelTSOModelContainer,
                                network::Networks.Network,
                                target_timepoints::Vector{Dates.DateTime},
                                scenarios::Vector{String},
                                generators_initial_state::SortedDict{String,GeneratorState},
                                firmness::Firmness,
                                preceding_tso_schedule::Schedule,
                                preceding_tso_actions::TSOActions,
                                always_link_commitment::Bool=false,
                                always_link_levels::Bool=false
                                )
    model = model_container.model
    imposable_model = model_container.imposable_model
    for generator in Networks.get_generators_of_type(network, Networks.IMPOSABLE)
        gen_initial_state = get_initial_state(generators_initial_state, imposable_gen)
        commitment_firmness = get_commitment_firmness(firmness, gen_id)
        power_level_firmness = get_power_level_firmness(firmness, gen_id)
        generator_reference_schedule = get_sub_schedule(preceding_tso_schedule, gen_id)
        add_imposable!(imposable_model, model,
                        generator, target_timepoints, scenarios,
                        gen_initial_state, commitment_firmness, power_level_firmness,
                        generator_reference_schedule, preceding_tso_actions,
                        always_link_commitment, always_link_levels)
    end
end

function add_slacks!(model_container::TSOBilevelTSOModelContainer,
                            network::Networks.Network,
                            target_timepoints::Vector{Dates.DateTime},
                            scenarios::Vector{String},
                            uncertainties_at_ech::UncertaintiesAtEch)
    #TODO: for now same as add_slacks!(::TSOModel,...)
    model = model_container.model
    slack_model = model_container.slack_model
    p_cut_conso = slack_model.p_cut_conso
    p_cut_conso_min = slack_model.p_cut_conso_min

    for ts in target_timepoints
        for s in scenarios
            conso_max = compute_load(uncertainties_at_ech, network, ts, s)
            name =  @sprintf("P_cut_conso_min[%s,%s]", ts, s)
            p_cut_conso_min[ts, s] = @variable(model, base_name=name, lower_bound=0., upper_bound=conso_max)
        end
    end

    buses = Networks.get_buses(network)
    add_cut_conso_by_bus!(model, p_cut_conso,
                        buses, target_timepoints, scenarios, uncertainties_at_ech)

    return slack_model
end

function add_rso_constraints!(model_container::TSOBilevelTSOModelContainer,
                            network::Networks.Network,
                            target_timepoints::Vector{Dates.DateTime},
                            scenarios::Vector{String},
                            uncertainties_at_ech::UncertaintiesAtEch)
    tso_model = model_container.model
    for branch in Networks.get_branches(network)
        branch_id = Networks.get_id(branch)
        flow_limit_l = Networks.get_limit(branch)

        for ts in target_timepoints
            for s in scenarios

                flow_l = 0.
                for bus in Networks.get_buses(network)
                    bus_id = Networks.get_id(bus)
                    ptdf = Networks.safeget_ptdf(network, branch_id, bus_id)

                    # + injections
                    for gen in Networks.get_generators(bus)
                        gen_id = Networks.get_id(gen)
                        gen_type = Networks.get_type(gen)
                        var_p_injected = get_p_injected(model_container, gen_type)[gen_id, ts, s]
                        flow_l += ptdf * var_p_injected
                    end

                    # - loads
                    flow_l -= ptdf * get_uncertainties(uncertainties_at_ech, bus_id, ts, s)

                    # + cutting loads ~ injections
                    flow_l += ptdf * model_container.slack_model.p_cut_conso[bus_id, ts, s]
                end

                cstr = @constraint(tso_model, -flow_limit_l <= flow_l <= flow_limit_l)
                println("RSO ",branch_id,",",ts,",",s,": ", cstr)

            end
        end
    end
end

function add_cut_conso_distribution_constraint!(tso_model_container::TSOBilevelTSOModelContainer,
                                            market_slack_model::TSOBilevelMarketSlackModel,
                                            target_timepoints, scenarios, network)
    tso_model = tso_model_container.model
    tso_slack_model = tso_model_container.slack_model
    buses_ids = Networks.get_id.(Networks.get_buses(network))
    for ts in target_timepoints
        for s in scenarios
            vars_sum = sum(tso_slack_model.p_cut_conso[bus_id, ts, s]
                            for bus_id in buses_ids)
            @constraint(tso_model, market_slack_model.p_cut_conso[ts, s] == vars_sum)
        end
    end
    return tso_model_container
end

function add_enr_distribution_constraint!(tso_model_container::TSOBilevelTSOModelContainer,
                                        market_limitable_model::TSOBilevelMarketLimitableModel,
                                        target_timepoints, scenarios, network)
    tso_model = tso_model_container.model
    limitable_model = tso_model_container.limitable_model
    limitables_ids = Networks.get_id.(Networks.get_generators_of_type(network, Networks.LIMITABLE))
    for ts in target_timepoints
        for s in scenarios
            vars_sum = sum(limitable_model.p_injected[gen_id, ts, s]
                            for gen_id in limitables_ids)
            @constraint(tso_model, market_limitable_model.p_injected[ts, s] == vars_sum)
        end
    end
    return tso_model_container
end

function add_capping_distribution_constraint!(tso_model_container::TSOBilevelTSOModelContainer,
                                            market_limitable_model::TSOBilevelMarketLimitableModel,
                                            target_timepoints, scenarios, network)
    tso_model = tso_model_container.model
    tso_limitable_model = tso_model_container.limitable_model
    limitables_ids = Networks.get_id.(Networks.get_generators_of_type(network, Networks.LIMITABLE))
    for ts in target_timepoints
        for s in scenarios
            vars_sum = sum(tso_limitable_model.p_capping[gen_id, ts, s]
                            for gen_id in limitables_ids)
            @constraint(tso_model, market_limitable_model.p_capping[ts, s] == vars_sum)
        end
    end
    return tso_model_container
end

function add_tso_constraints!(bimodel_container::TSOBilevelModel,
                            target_timepoints, scenarios, network,
                            uncertainties_at_ech::UncertaintiesAtEch)
    tso_model_container::TSOBilevelTSOModelContainer = bimodel_container.upper
    market_model_container::TSOBilevelMarketModelContainer = bimodel_container.lower

    #add_operational_constraints!()
    add_rso_constraints!(tso_model_container,
                        network, target_timepoints, scenarios,
                        uncertainties_at_ech)
    add_cut_conso_distribution_constraint!(tso_model_container,
                                        market_model_container.slack_model,
                                        target_timepoints, scenarios, network)
    add_enr_distribution_constraint!(tso_model_container,
                                    market_model_container.limitable_model,
                                    target_timepoints, scenarios, network)
    add_capping_distribution_constraint!(tso_model_container,
                                    market_model_container.limitable_model,
                                    target_timepoints, scenarios, network)

    return bimodel_container
end

function create_tso_objectives!(model_container::TSOBilevelTSOModelContainer,
                                market_model_container::TSOBilevelMarketModelContainer,
                                capping_cost, cut_conso_cost)
    objective_model = model_container.objective_model

    # model_container.imposable_cost

    # limitable_cost : capping (fr. ecretement)
    objective_model.limitable_cost += coeffxsum(model_container.limitable_model.p_capping_min, capping_cost)

    # cost for cutting load/consumption
    objective_model.penalty += coeffxsum(model_container.slack_model.p_cut_conso_min, cut_conso_cost)
    # #FIXME : looks necessary otherwise TSO will always consider that market can feasibly cut all conso
    # objective_model.penalty += coeffxsum(market_model_container.slack_model.p_cut_conso, cut_conso_cost)

    objective_model.full_obj = ( objective_model.imposable_cost +
                                objective_model.limitable_cost +
                                objective_model.penalty )
    @objective(model_container.model, Min, objective_model.full_obj)
    return model_container
end

##########################################################
#        lower problem : Market functtons  : TSOBilevelMarketModelContainer
##########################################################

function create_market_vars!(model_container::TSOBilevelMarketModelContainer,
                            network::Networks.Network,
                            target_timepoints::Vector{Dates.DateTime},
                            # generators_initial_state::SortedDict{String,GeneratorState},
                            scenarios::Vector{String},
                            uncertainties_at_ech::UncertaintiesAtEch
                            # firmness::Firmness,
                            # preceding_tso_schedule::Schedule,
                            # preceding_tso_actions::TSOActions,
                            # configs::TSOBilevelConfigs
                            )
    add_limitables!(model_container,
                    network, target_timepoints, scenarios, uncertainties_at_ech)
    # add_imposables!(model_container)
    add_slacks!(model_container, network, target_timepoints, scenarios, uncertainties_at_ech)
end

function add_limitables!(model_container::TSOBilevelMarketModelContainer,
                        network::Networks.Network,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        uncertainties_at_ech::UncertaintiesAtEch
                        #firmness::Firmness,
                        #always_link_scenarios_limit=false
                        )
    model = model_container.model
    limitable_model = model_container.limitable_model
    for ts in target_timepoints
        for s in scenarios
            enr_max = compute_prod(uncertainties_at_ech, network, ts, s)
            name =  @sprintf("P_injected[%s,%s]", ts, s)
            limitable_model.p_injected[ts, s] = @variable(model, base_name=name, lower_bound=0., upper_bound=enr_max)
            name =  @sprintf("P_capping[%s,%s]", ts, s)
            limitable_model.p_capping[ts, s] = @variable(model, base_name=name, lower_bound=0., upper_bound=enr_max)
        end
    end
    return model_container
end

function add_imposables!(model_container::TSOBilevelMarketModelContainer)
end

function add_slacks!(model_container::TSOBilevelMarketModelContainer,
                    network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch)
    model = model_container.model
    slack_model = model_container.slack_model
    for ts in target_timepoints
        for s in scenarios
            conso_max = compute_load(uncertainties_at_ech, network, ts, s)
            name =  @sprintf("P_cut_conso[%s,%s]", ts, s)
            slack_model.p_cut_conso[ts, s] = @variable(model, base_name=name,
                                                        lower_bound=0., upper_bound=conso_max)
        end
    end
    return slack_model
end

function add_eod_constraints!(market_model_container::TSOBilevelMarketModelContainer,
                            target_timepoints, scenarios,
                            network, uncertainties_at_ech::UncertaintiesAtEch)
    for ts in target_timepoints
        for s in scenarios
            prod = compute_prod(uncertainties_at_ech, network, ts, s)
            prod -= market_model_container.limitable_model.p_capping[ts,s]
            prod += sum_injections(market_model_container.imposable_model, ts, s)

            conso = compute_load(uncertainties_at_ech, network, ts, s)
            conso -= market_model_container.slack_model.p_cut_conso[ts,s]

            cstr = @constraint(market_model_container.model, prod == conso)
            println("EOD ",ts,",",s,": ", cstr)
        end
    end
    return market_model_container
end

function add_link_capping_constraint!(market_model_container::TSOBilevelMarketModelContainer,
                                tso_limitable_model::TSOBilevelTSOLimitableModel,
                                target_timepoints, scenarios, network)
    market_model = market_model_container.model
    market_limitable_model = market_model_container.limitable_model
    for ts in target_timepoints
        for s in scenarios
            @constraint(market_model,
                        tso_limitable_model.p_capping_min[ts,s] <= market_limitable_model.p_capping[ts,s])
        end
    end
    return market_model_container
end

function add_link_cut_conso_constraint!(market_model_container::TSOBilevelMarketModelContainer,
                                tso_slack_model::TSOBilevelTSOSlackModel,
                                target_timepoints, scenarios, network)
    market_model = market_model_container.model
    market_slack_model = market_model_container.slack_model
    for ts in target_timepoints
        for s in scenarios
            @constraint(market_model,
                        tso_slack_model.p_cut_conso_min[ts,s] <= market_slack_model.p_cut_conso[ts,s])
        end
    end
    return market_model_container
end


function add_market_constraints!(bimodel_container::TSOBilevelModel,
                            target_timepoints, scenarios, network,
                            uncertainties_at_ech::UncertaintiesAtEch)
    tso_model_container::TSOBilevelTSOModelContainer = bimodel_container.upper
    market_model_container::TSOBilevelMarketModelContainer = bimodel_container.lower

    add_eod_constraints!(market_model_container,
                        target_timepoints, scenarios,
                        network, uncertainties_at_ech)
    add_link_capping_constraint!(market_model_container,
                                tso_model_container.limitable_model,
                                target_timepoints, scenarios, network)
    add_link_cut_conso_constraint!(market_model_container,
                                tso_model_container.slack_model,
                                target_timepoints, scenarios, network)

    return bimodel_container
end

function create_market_objectives!(model_container::TSOBilevelMarketModelContainer,
                                capping_cost, cut_conso_cost)
    objective_model = model_container.objective_model

    # model_container.imposable_cost

    # limitable_cost : capping (fr. ecretement)
    objective_model.limitable_cost += coeffxsum(model_container.limitable_model.p_capping, capping_cost)

    # cost for cutting load/consumption
    objective_model.penalty += coeffxsum(model_container.slack_model.p_cut_conso, cut_conso_cost)

    objective_model.full_obj = ( objective_model.imposable_cost +
                                objective_model.limitable_cost +
                                objective_model.penalty )
    @objective(model_container.model, Min, objective_model.full_obj)
    return model_container
end

#############################
# Utils
#############################
function coeffxsum(vars_dict::AbstractDict{T,V}, coeff::Float64
                )::GenericAffExpr{Float64, BilevelJuMP.BilevelVariableRef} where T <: Tuple where V <: AbstractVariableRef
    terms = [var_l=>coeff for (_, var_l) in vars_dict]
    result = GenericAffExpr{Float64, BilevelJuMP.BilevelVariableRef}(0., terms)
    return result
end

##########################################################
#        TSOBilevel
##########################################################
function tso_bilevel(network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    generators_initial_state::SortedDict{String,GeneratorState},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch,
                    firmness::Firmness,
                    preceding_market_schedule::Schedule,
                    preceding_tso_schedule::Schedule,
                    preceding_tso_actions::TSOActions,
                    gratis_starts::Set{Tuple{String,Dates.DateTime}},
                    configs::TSOBilevelConfigs
                    )

    bimodel_container_l = TSOBilevelModel()

    create_tso_vars!(bimodel_container_l.upper,
                    network, target_timepoints, generators_initial_state, scenarios,
                    uncertainties_at_ech, firmness, preceding_tso_schedule, preceding_tso_actions,
                    configs)
    create_market_vars!(bimodel_container_l.lower,
                        network, target_timepoints, scenarios, uncertainties_at_ech)

    #constraints that use upper and lower vars at the same time
    add_tso_constraints!(bimodel_container_l, target_timepoints, scenarios, network, uncertainties_at_ech)
    add_market_constraints!(bimodel_container_l, target_timepoints, scenarios, network, uncertainties_at_ech)

    create_tso_objectives!(bimodel_container_l.upper, bimodel_container_l.lower, configs.capping_cost, configs.cut_conso_penalty)
    create_market_objectives!(bimodel_container_l.lower, configs.capping_cost, configs.cut_conso_penalty)

    solve!(bimodel_container_l, configs.problem_name, configs.out_path) #FIXME write(Bilevel) not supported

    return bimodel_container_l
end
