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
    big_m = 1e9
end

##########################################################
#        upper problem : TSO
##########################################################

@with_kw struct TSOBilevelTSOLimitableModel <: AbstractLimitableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    p_limit = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_is_limited = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    p_limit_x_is_limited = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    p_capping = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #ts,s
    p_capping_min = SortedDict{Tuple{DateTime,String},VariableRef}();
end

@with_kw struct TSOBilevelTSOImposableModel <: AbstractImposableModel
    #gen,ts,s
    p_tso_min = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    p_tso_max = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_start = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_on = SortedDict{Tuple{String,DateTime,String},VariableRef}();
end

@with_kw struct TSOBilevelTSOSlackModel <: AbstractSlackModel
    #bus,ts,s #Loss of Load
    p_cut_conso = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #ts,s
    p_cut_conso_min = SortedDict{Tuple{DateTime,String},VariableRef}();
end

@with_kw mutable struct TSOBilevelTSOObjectiveModel <: AbstractObjectiveModel
    limitable_cost = GenericAffExpr{Float64, VariableRef}()
    imposable_cost = GenericAffExpr{Float64, VariableRef}()

    penalty = GenericAffExpr{Float64, VariableRef}()

    full_obj = GenericAffExpr{Float64, VariableRef}()
end

##########################################################
#        lower problem : Market
##########################################################
@with_kw struct TSOBilevelMarketLimitableModel <: AbstractLimitableModel
    #ts,s #FIXME not sure if this should be a lower or an upper variable
    p_injected = SortedDict{Tuple{DateTime,String},VariableRef}();
    #ts,s
    p_capping = SortedDict{Tuple{DateTime,String},VariableRef}();
end

@with_kw struct TSOBilevelMarketImposableModel <: AbstractImposableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
end

@with_kw struct TSOBilevelMarketSlackModel <: AbstractSlackModel
    #ts,s
    p_cut_conso = SortedDict{Tuple{DateTime,String},VariableRef}();
end

@with_kw mutable struct TSOBilevelMarketObjectiveModel <: AbstractObjectiveModel
    limitable_cost = GenericAffExpr{Float64, VariableRef}()
    imposable_cost = GenericAffExpr{Float64, VariableRef}()

    penalty = GenericAffExpr{Float64, VariableRef}()

    full_obj = GenericAffExpr{Float64, VariableRef}()
end

##########################################################
#        TSOBilevel Model
##########################################################

@with_kw struct TSOBilevelTSOModelContainer <: AbstractModelContainer
    model::Model
    limitable_model::TSOBilevelTSOLimitableModel = TSOBilevelTSOLimitableModel()
    imposable_model::TSOBilevelTSOImposableModel = TSOBilevelTSOImposableModel()
    slack_model::TSOBilevelTSOSlackModel = TSOBilevelTSOSlackModel()
    objective_model::TSOBilevelTSOObjectiveModel = TSOBilevelTSOObjectiveModel()
end
@with_kw struct TSOBilevelMarketModelContainer <: AbstractModelContainer
    model::Model
    limitable_model::TSOBilevelMarketLimitableModel = TSOBilevelMarketLimitableModel()
    imposable_model::TSOBilevelMarketImposableModel = TSOBilevelMarketImposableModel()
    slack_model::TSOBilevelMarketSlackModel = TSOBilevelMarketSlackModel()
    objective_model::TSOBilevelMarketObjectiveModel = TSOBilevelMarketObjectiveModel()
end
@with_kw struct TSOBilevelKKTModelContainer <: AbstractModelContainer
    #TODO create adequate struct to link each dual kkt variable, indicator variable, and constraint to each other
    # e.g.
    # eod_model = ts,s -> Struct{dual, indicator, ConstraintRef}
    # imposable_min = id,ts,s -> Struct{dual, indicator, ConstraintRef} or Struct{dual, Nothing, ConstraintRef}
    # than simply call reformulate_kkt(cstr) when building lower problem's constraints provided that objective is created first
    model::Model
    #ts,s
    eod_duals::SortedDict{Tuple{DateTime,String},VariableRef} =
        SortedDict{Tuple{DateTime,String},VariableRef}()
    capping_duals::SortedDict{Tuple{DateTime,String},VariableRef} =
        SortedDict{Tuple{DateTime,String},VariableRef}()
    capping_indicators::SortedDict{Tuple{DateTime,String},VariableRef} =
        SortedDict{Tuple{DateTime,String},VariableRef}()
    cut_conso_duals::SortedDict{Tuple{DateTime,String},VariableRef} =
        SortedDict{Tuple{DateTime,String},VariableRef}()
    cut_conso_indicators::SortedDict{Tuple{DateTime,String},VariableRef} =
        SortedDict{Tuple{DateTime,String},VariableRef}()
    #imposable_id,ts,s
    # pmin_duals::SortedDict{Tuple{String,DateTime,String},VariableRef} =
        # SortedDict{Tuple{String,DateTime,String},VariableRef}()
    # pmin_indicators::SortedDict{Tuple{String,DateTime,String},VariableRef} =
        # SortedDict{Tuple{String,DateTime,String},VariableRef}()
    # pmax_duals::SortedDict{Tuple{String,DateTime,String},VariableRef} =
        # SortedDict{Tuple{String,DateTime,String},VariableRef}()
    # pmax_indicators::SortedDict{Tuple{String,DateTime,String},VariableRef} =
        # SortedDict{Tuple{String,DateTime,String},VariableRef}()
end
TSOBilevelModel = BilevelModelContainer{TSOBilevelTSOModelContainer, TSOBilevelMarketModelContainer, TSOBilevelKKTModelContainer}
function BilevelModelContainer{TSOBilevelTSOModelContainer,TSOBilevelMarketModelContainer,TSOBilevelKKTModelContainer}()
    bilevel_model = Model()
    upper = TSOBilevelTSOModelContainer(model=bilevel_model)
    lower = TSOBilevelMarketModelContainer(model=bilevel_model)
    kkt_model = TSOBilevelKKTModelContainer(model=bilevel_model)
    return BilevelModelContainer(bilevel_model, upper, lower, kkt_model)
end


function has_positive_slack(model_container::TSOBilevelModel)::Bool
    return has_positive_value(model_container.lower.slack_model.p_cut_conso) #If TSO cut => market did too
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
            limitable_model.p_capping[gen_id, ts, s] = @variable(model, base_name=name, lower_bound=0., upper_bound=p_enr)
            name =  @sprintf("c_define_e[%s,%s,%s]", gen_id, ts, s)
            @constraint(model, limitable_model.p_capping[gen_id, ts, s] == p_uncert - p_inj_var, base_name=name)
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

                name = @sprintf("c_RSO[%s,%s,%s]",branch_id,ts,s)
                cstr = @constraint(tso_model, -flow_limit_l <= flow_l <= flow_limit_l, base_name=name)
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
            name = @sprintf("c_dist_LOL[%s,%s]",ts,s)
            vars_sum = sum(tso_slack_model.p_cut_conso[bus_id, ts, s]
                            for bus_id in buses_ids)
            @constraint(tso_model, market_slack_model.p_cut_conso[ts, s] == vars_sum, base_name=name)
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
            name = @sprintf("c_dist_penr[%s,%s]",ts,s)
            vars_sum = sum(limitable_model.p_injected[gen_id, ts, s]
                            for gen_id in limitables_ids)
            @constraint(tso_model, market_limitable_model.p_injected[ts, s] == vars_sum, base_name=name)
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
            name = @sprintf("c_dist_e[%s,%s]",ts,s)
            vars_sum = sum(tso_limitable_model.p_capping[gen_id, ts, s]
                            for gen_id in limitables_ids)
            @constraint(tso_model, market_limitable_model.p_capping[ts, s] == vars_sum, base_name=name)
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

    # objective_model.imposable_cost

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
                            kkt_model_container::TSOBilevelKKTModelContainer,
                            target_timepoints, scenarios,
                            network, uncertainties_at_ech::UncertaintiesAtEch)
    @assert(market_model_container.model === kkt_model_container.model)

    for ts in target_timepoints
        for s in scenarios
            prod = compute_prod(uncertainties_at_ech, network, ts, s)
            prod -= market_model_container.limitable_model.p_capping[ts,s]
            prod += sum_injections(market_model_container.imposable_model, ts, s)

            conso = compute_load(uncertainties_at_ech, network, ts, s)
            conso -= market_model_container.slack_model.p_cut_conso[ts,s]

            name = @sprintf("c_EOD[%s,%s]",ts,s)
            cstr = @constraint(market_model_container.model, prod == conso, base_name=name)
            println("EOD ",ts,",",s,": ", cstr)

            #create duals relative to EOD constraint
            add_dual!(kkt_model_container.model, kkt_model_container.eod_duals, (ts,s), name, false)
        end
    end
    return market_model_container
end

function add_link_capping_constraint!(market_model_container::TSOBilevelMarketModelContainer,
                                        kkt_model_container::TSOBilevelKKTModelContainer,
                                    tso_limitable_model::TSOBilevelTSOLimitableModel,
                                    target_timepoints, scenarios, network)
    market_model = market_model_container.model
    market_limitable_model = market_model_container.limitable_model
    for ts in target_timepoints
        for s in scenarios
            name = @sprintf("c_min_e[%s,%s]",ts,s)
            @constraint(market_model,
                        tso_limitable_model.p_capping_min[ts,s] <= market_limitable_model.p_capping[ts,s],
                        base_name=name)

            #create duals and indicators relative to RSO min capping constraint
            add_dual_and_indicator!(kkt_model_container.model,
                                    kkt_model_container.capping_duals, kkt_model_container.capping_indicators, (ts,s),
                                    name, true)
        end
    end
    return market_model_container
end

function add_link_cut_conso_constraint!(market_model_container::TSOBilevelMarketModelContainer,
                                        kkt_model_container::TSOBilevelKKTModelContainer,
                                    tso_slack_model::TSOBilevelTSOSlackModel,
                                    target_timepoints, scenarios, network)
    market_model = market_model_container.model
    market_slack_model = market_model_container.slack_model
    for ts in target_timepoints
        for s in scenarios
            name = @sprintf("c_min_lol[%s,%s]",ts,s)
            @constraint(market_model,
                        tso_slack_model.p_cut_conso_min[ts,s] <= market_slack_model.p_cut_conso[ts,s],
                        base_name=name)

            #create duals and indicators relative to RSO min capping constraint
            add_dual_and_indicator!(kkt_model_container.model,
                                    kkt_model_container.cut_conso_duals, kkt_model_container.cut_conso_indicators, (ts,s),
                                    name, true)
        end
    end
    return market_model_container
end


function add_market_constraints!(bimodel_container::TSOBilevelModel,
                            target_timepoints, scenarios, network,
                            uncertainties_at_ech::UncertaintiesAtEch)
    tso_model_container::TSOBilevelTSOModelContainer = bimodel_container.upper
    market_model_container::TSOBilevelMarketModelContainer = bimodel_container.lower
    kkt_model_container::TSOBilevelKKTModelContainer = bimodel_container.kkt_model

    # @constraint(market_model_container.model,
    #             market_model_container.slack_model.p_cut_conso[target_timepoints[1], scenarios[1]]==0.,
    #             base_name = "DBG_temp_constraint")

    add_eod_constraints!(market_model_container, kkt_model_container,
                        target_timepoints, scenarios,
                        network, uncertainties_at_ech)
    add_link_capping_constraint!(market_model_container, kkt_model_container,
                                tso_model_container.limitable_model,
                                target_timepoints, scenarios, network)
    add_link_cut_conso_constraint!(market_model_container, kkt_model_container,
                                tso_model_container.slack_model,
                                target_timepoints, scenarios, network)
    #add_imposables_constraint!()

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

    return model_container
end

##########################################################
#        kkt reformulation : TSOBilevelKKTModelContainer
##########################################################

function add_dual_and_indicator!(kkt_model::Model, duals_dict, indicators_dict,
                                key, name,
                                is_positive::Bool)

    add_dual!(kkt_model, duals_dict, key, name, is_positive)

    indicators_dict[key] = @variable(kkt_model, binary=true, base_name="indicator_"*name)

    return duals_dict[key] , indicators_dict[key]
end

function add_dual!(kkt_model::Model, duals_dict,
                    key, name,
                    is_positive::Bool)
    if is_positive
        duals_dict[key] = @variable(kkt_model, lower_bound=0., base_name="dual_"*name)
    else
        duals_dict[key] = @variable(kkt_model, base_name="dual_"*name)
    end

    return duals_dict[key]
end

function add_kkt_stationarity_constraints!(kkt_model::TSOBilevelKKTModelContainer,
                                            target_timepoints, scenarios,
                                            capping_cost, cut_conso_cost)
    #FIXME can be generic by iterating on lower variables to construct each stationarity constraint
    # iterate on the objective and lower constraints to extract their coefficients, but need to link each cnstraint to its dual var
    add_capping_stationarity_constraints!(kkt_model, target_timepoints, scenarios, capping_cost)
    add_cut_conso_stationarity_constraints!(kkt_model, target_timepoints, scenarios, cut_conso_cost)
    # add_imposable_stationarity_constraints
end

function add_cut_conso_stationarity_constraints!(kkt_model::TSOBilevelKKTModelContainer,
                                                target_timepoints, scenarios, cut_conso_cost)
    for ts in target_timepoints
        for s in scenarios
            name = @sprintf("c_stationarity_lol[%s,%s]",ts,s)
            @constraint(kkt_model.model,
                        cut_conso_cost + kkt_model.eod_duals[ts,s] - kkt_model.cut_conso_duals[ts,s] == 0,
                        base_name=name)
        end
    end
end

function add_capping_stationarity_constraints!(kkt_model::TSOBilevelKKTModelContainer,
                                                target_timepoints, scenarios, capping_cost)
    for ts in target_timepoints
        for s in scenarios
            name = @sprintf("c_stationarity_e[%s,%s]",ts,s)
            @constraint(kkt_model.model,
                        capping_cost - kkt_model.eod_duals[ts,s] - kkt_model.capping_duals[ts,s] == 0,
                        base_name=name)
        end
    end
end

function add_kkt_complementarity_constraints!(model_container::TSOBilevelModel,
                                            big_m, target_timepoints, scenarios)
    #FIXME can be done iteratively and generically if we loop on constraint expressions and know their corresponding kkt vars
    add_emin_complementarity_constraints!(model_container, big_m, target_timepoints, scenarios)
    add_lolmin_complementarity_constraints!(model_container, big_m, target_timepoints, scenarios)
    # add_pmin_complementarity_constraints!()
    # add_pmax_complementarity_constraints!()
end

function add_emin_complementarity_constraints!(model_container::TSOBilevelModel,
                                            big_m, target_timepoints, scenarios)
    tso_limitable_model = model_container.upper.limitable_model
    market_limitable_model = model_container.lower.limitable_model
    kkt_model = model_container.kkt_model

    for ts in target_timepoints
        for s in scenarios
            kkt_var = kkt_model.capping_duals[ts,s]
            cstr_expr = market_limitable_model.p_capping[ts,s] - tso_limitable_model.p_capping_min[ts,s]
            b_indicator = kkt_model.capping_indicators[ts,s]
            ub_cstr = compute_ub(cstr_expr, big_m)
            formulate_complementarity_constraints!(kkt_model.model, kkt_var, cstr_expr, b_indicator, big_m, ub_cstr)
        end
    end
    return model_container
end

function add_lolmin_complementarity_constraints!(model_container::TSOBilevelModel,
                                                big_m, target_timepoints, scenarios)
    tso_slack_model = model_container.upper.slack_model
    market_slack_model = model_container.lower.slack_model
    kkt_model = model_container.kkt_model

    for ts in target_timepoints
        for s in scenarios
            kkt_var = kkt_model.cut_conso_duals[ts,s]
            cstr_expr = market_slack_model.p_cut_conso[ts,s] - tso_slack_model.p_cut_conso_min[ts,s]
            b_indicator = kkt_model.cut_conso_indicators[ts,s]
            ub_cstr = compute_ub(cstr_expr, big_m)
            formulate_complementarity_constraints!(kkt_model.model, kkt_var, cstr_expr, b_indicator, big_m, ub_cstr)
        end
    end
    return model_container
end

function add_pmin_complementarity_constraints!()
    error("TODO")
end

function add_pmax_complementarity_constraints!()
    error("TODO")
end


#############################
# Utils
#############################
function coeffxsum(vars_dict::AbstractDict{T,V}, coeff::Float64
                )::GenericAffExpr{Float64, VariableRef} where T <: Tuple where V <: AbstractVariableRef
    terms = [var_l=>coeff for (_, var_l) in vars_dict]
    result = GenericAffExpr{Float64, VariableRef}(0., terms)
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
    @assert(configs.big_m >= configs.cut_conso_penalty)
    @assert(configs.big_m >= configs.capping_cost)

    create_tso_vars!(bimodel_container_l.upper,
                    network, target_timepoints, generators_initial_state, scenarios,
                    uncertainties_at_ech, firmness, preceding_tso_schedule, preceding_tso_actions,
                    configs)
    create_market_vars!(bimodel_container_l.lower,
                        network, target_timepoints, scenarios, uncertainties_at_ech)

    #this is the expression no objective is added to the jump model
    create_market_objectives!(bimodel_container_l.lower, configs.capping_cost, configs.cut_conso_penalty)

    #constraints may use upper and lower vars at the same time
    add_tso_constraints!(bimodel_container_l, target_timepoints, scenarios, network, uncertainties_at_ech)
    #kkt primal feasibility + variables creation
    add_market_constraints!(bimodel_container_l, target_timepoints, scenarios, network, uncertainties_at_ech)
    #kkt stationarity
    add_kkt_stationarity_constraints!(bimodel_container_l.kkt_model, target_timepoints, scenarios, configs.capping_cost, configs.cut_conso_penalty)
    #kkt complementarity
    add_kkt_complementarity_constraints!(bimodel_container_l, configs.big_m, target_timepoints, scenarios)

    create_tso_objectives!(bimodel_container_l.upper, bimodel_container_l.lower, configs.capping_cost, configs.cut_conso_penalty)

    solve!(bimodel_container_l, configs.problem_name, configs.out_path)
    @info("Lower Objective Value : $(value(bimodel_container_l.lower.objective_model.full_obj))")

    return bimodel_container_l
end