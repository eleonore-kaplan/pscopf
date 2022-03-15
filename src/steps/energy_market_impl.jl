using .Networks

using JuMP
using Dates
using DataStructures
using Printf
using Parameters

@with_kw mutable struct EnergyMarketConfigs
    force_limitables::Bool = true
    cut_conso_penalty = 1e7
    out_path = nothing
    problem_name = "EnergyMarket"
end

@with_kw struct EnergyMarketLimitableModel <: AbstractLimitableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #ts,s
    p_capping = SortedDict{Tuple{DateTime,String},VariableRef}();
    #firmness_constraints
end

@with_kw struct EnergyMarketImposableModel <: AbstractImposableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_start = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_on = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #commitment_constraints = Dict{Tuple{String,DateTime,String},ConstraintRef}();
    #firmness_constraints
end

@with_kw struct EnergyMarketSlackModel <: AbstractSlackModel
    #ts,s
    p_cut_conso = SortedDict{Tuple{DateTime,String},VariableRef}();
end

@with_kw mutable struct EnergyMarketObjectiveModel <: AbstractObjectiveModel
    prop_cost = AffExpr(0)
    start_cost = AffExpr(0)
    penalty = AffExpr(0)

    full_obj = AffExpr(0)
end


@with_kw mutable struct EnergyMarketModel <: AbstractModelContainer
    model::Model = Model()
    limitable_model::EnergyMarketLimitableModel = EnergyMarketLimitableModel()
    imposable_model::EnergyMarketImposableModel = EnergyMarketImposableModel()
    slack_model::EnergyMarketSlackModel = EnergyMarketSlackModel()
    objective_model::EnergyMarketObjectiveModel = EnergyMarketObjectiveModel()
    eod_constraint::SortedDict{Tuple{Dates.DateTime,String}, ConstraintRef} =
        SortedDict{Tuple{Dates.DateTime,String}, ConstraintRef}()
    #v_flow = Dict{Tuple{String,DateTime,String},VariableRef}()
    status::PSCOPFStatus = pscopf_UNSOLVED
end

"""
    energy_market
# Arguments
    - `network::Networks.Network`
    - `target_timepoints::Vector{Dates.DateTime}`
    - `generators_initial_state::SortedDict{String,GeneratorState}` :
        The ON/OFF state of each generator just before the first targe ttimepoint.
    - `scenarios::Vector{String}` : considered scenarios
    - `uncertainties_at_ech::UncertaintiesAtEch` :
        The considered limitables injections and bus consumption realisations per scenario
         for the current timepoint of execution (i.e. `ech`).
    - `firmness::Firmness` : The required level of firmness for commitment and power level decisions
    - `reference_schedule::Schedule` : The reference schedule used to set already decided values.
    - `gratis_starts::Set{Tuple{String,Dates.DateTime}}` :
        Tuples of (gen_id, ts) giving already paid for starting decisions. So if the market starts
         unit gen_id at timestep ts, it will not pay the starting cost.
    - `cut_conso_cost::Float64` : penalty cost for not satisfying 1MW of demand.
    - `force_limitables::Bool` : If true, each limitable will be forced to its given value in uncertainties.
    - `out_path` : Path to the location where files will be printed. (Defaults to `nothing`)
        If `nothing`, no output files will be printed
    - `problem_name` : name of the treated problem used for the output files' names
"""
function energy_market(network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    generators_initial_state::SortedDict{String,GeneratorState},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch,
                    firmness::Firmness,
                    reference_schedule::Schedule,
                    gratis_starts::Set{Tuple{String,Dates.DateTime}},
                    configs::EnergyMarketConfigs
                    )

    model_container_l = EnergyMarketModel()

    add_limitables!(model_container_l,
                    network, target_timepoints,
                    scenarios,
                    uncertainties_at_ech,
                    force_limitables=configs.force_limitables,
                    has_global_capping_vars=true,
                    )

    add_imposables!(model_container_l,
                    network, target_timepoints,
                    scenarios,
                    generators_initial_state,
                    firmness, reference_schedule)

    add_slacks!(model_container_l,
                network, target_timepoints, scenarios,
                uncertainties_at_ech)


    add_eod_constraint!(model_container_l,
                        network, target_timepoints, scenarios,
                        uncertainties_at_ech
                        )

    add_objective!(model_container_l, network, gratis_starts, configs.cut_conso_penalty)

    solve!(get_model(model_container_l), configs.problem_name, configs.out_path)

    status_l = get_status(model_container_l)

    @info "pscopf model status: $status_l"
    @info "Termination status : $(termination_status(model_container_l.model))"
    @info "Objective value : $(objective_value(model_container_l.model))"

    return model_container_l
end

function add_objective!(model_container::EnergyMarketModel, network, gratis_starts, cut_conso_cost)
    # No cost for starting limitables

    # cost for starting imposables
    for ((gen_id,ts,_), b_start_var) in model_container.imposable_model.b_start
        if (gen_id,ts) in gratis_starts
            @info(@sprintf("ignore starting cost of %s at %s", gen_id, ts))
            continue
        end
        generator = Networks.get_generator(network, gen_id)
        gen_start_cost = Networks.get_start_cost(generator)
        model_container.objective_model.start_cost += b_start_var * gen_start_cost
    end

    # cost for using limitables : but most of the times these are fixed
    for ((gen_id,_,_), p_injected_var) in model_container.limitable_model.p_injected
        generator = Networks.get_generator(network, gen_id)
        gen_prop_cost = Networks.get_prop_cost(generator)
        model_container.objective_model.prop_cost += p_injected_var * gen_prop_cost
    end

    # cost for using imposables
    for ((gen_id,_,_), p_injected_var) in model_container.imposable_model.p_injected
        generator = Networks.get_generator(network, gen_id)
        gen_prop_cost = Networks.get_prop_cost(generator)
        model_container.objective_model.prop_cost += p_injected_var * gen_prop_cost
    end

    # cost for cutting load/consumption
    for ((_,_), p_cut_conso) in model_container.slack_model.p_cut_conso
        model_container.objective_model.penalty += cut_conso_cost * p_cut_conso
    end

    model_container.objective_model.full_obj = ( model_container.objective_model.start_cost +
                                                model_container.objective_model.prop_cost +
                                                model_container.objective_model.penalty )
    @objective(model_container.model, Min, model_container.objective_model.full_obj)
    return model_container
end

function add_imposable!(imposable_model::EnergyMarketImposableModel, model::Model,
                        generator::Networks.Generator,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        generator_initial_state::GeneratorState,
                        commitment_firmness::Union{Missing,SortedDict{Dates.DateTime, DecisionFirmness}}, #by ts #or Missing
                        power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                        generator_reference_schedule::GeneratorSchedule
                        )
    gen_id = Networks.get_id(generator)
    p_min = Networks.get_p_min(generator)
    p_max = Networks.get_p_max(generator)
    for ts in target_timepoints
        for s in scenarios
            add_p_injected!(imposable_model, model, gen_id, ts, s, p_max, false)
        end
    end

    add_power_level_firmness_constraints!(model, generator,
                                        imposable_model.p_injected,
                                        target_timepoints, scenarios,
                                        power_level_firmness,
                                        generator_reference_schedule
                                        )

    if p_min > 0
        add_commitment!(imposable_model, model, generator,
                        target_timepoints, scenarios, generator_initial_state
                        )
        add_commitment_firmness_constraints!(model, generator,
                                            imposable_model.b_on,
                                            imposable_model.b_start,
                                            target_timepoints, scenarios,
                                            generator_initial_state,
                                            commitment_firmness,
                                            generator_reference_schedule
                                            )
    end

    return imposable_model, model
end

function add_limitable!(limitable_model::EnergyMarketLimitableModel, model::Model,
                        generator::Networks.Generator,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        inject_uncertainties::InjectionUncertainties,
                        force_limitables::Bool,
                        )
    gen_id = Networks.get_id(generator)
    gen_pmax = Networks.get_p_max(generator)
    for ts in target_timepoints
        for s in scenarios
            p_enr = min(gen_pmax, inject_uncertainties[ts][s]) #FIXME and limit induced by the TSO, potentially (for other markets, this for now does not look at the TSO constraints)
            add_p_injected!(limitable_model, model, gen_id, ts, s, p_enr, force_limitables)
        end
    end

    return limitable_model, model
end

function add_imposables!(model_container::EnergyMarketModel, network::Networks.Network,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        generators_initial_state::SortedDict{String,GeneratorState},
                        firmness::Firmness,
                        reference_schedule::Schedule
                        )
    imposable_generators = Networks.get_generators_of_type(network, Networks.IMPOSABLE)
    for imposable_gen in imposable_generators
        gen_id = Networks.get_id(imposable_gen)
        # gen_commitment = get_commitment_firmness(firmness, gen_id)
        gen_initial_state = get_initial_state(generators_initial_state, imposable_gen)
        add_imposable!(model_container.imposable_model, model_container.model,
                        imposable_gen,
                        target_timepoints,
                        scenarios,
                        gen_initial_state,
                        get_commitment_firmness(firmness, gen_id),
                        get_power_level_firmness(firmness, gen_id),
                        get_sub_schedule(reference_schedule, gen_id)
                        )
    end
    return model_container.imposable_model
end

function add_limitables!(model_container::EnergyMarketModel, network::Networks.Network,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        uncertainties_at_ech::UncertaintiesAtEch;
                        force_limitables::Bool=false,
                        has_global_capping_vars::Bool=false,
                        )
    limitable_model = model_container.limitable_model
    model = model_container.model

    limitable_generators = Networks.get_generators_of_type(network, Networks.LIMITABLE)
    for limitable_gen in limitable_generators
        gen_id = Networks.get_id(limitable_gen)
        add_limitable!(limitable_model, model,
                        limitable_gen,
                        target_timepoints,
                        scenarios,
                        get_uncertainties(uncertainties_at_ech, gen_id),
                        force_limitables,
                        )
    end

    if has_global_capping_vars
        for ts in target_timepoints
            for s in scenarios
                name =  @sprintf("P_capping[%s,%s]", ts, s)
                limitable_model.p_capping[ts, s] = @variable(model, base_name=name, lower_bound=0.)
                @constraint(model, limitable_model.p_capping[ts, s] <= sum_injections(limitable_model, ts, s))
            end
        end
    end

    return model_container.limitable_model
end

function add_slacks!(model_container::EnergyMarketModel,
                    network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch)
    model = model_container.model
    slack_model = model_container.slack_model
    for ts in target_timepoints
        for s in scenarios
            name =  @sprintf("P_cut_conso[%s,%s]", ts, s)
            load = compute_load(uncertainties_at_ech, network, ts, s)
            slack_model.p_cut_conso[ts, s] = @variable(model, base_name=name,
                                                        lower_bound=0., upper_bound=load)
        end
    end
    return model_container.slack_model
end

function add_eod_constraint!(model_container::EnergyMarketModel,
                            network::Networks.Network,
                            target_timepoints::Vector{Dates.DateTime},
                            scenarios::Vector{String},
                            uncertainties_at_ech::UncertaintiesAtEch)
    for ts in target_timepoints
        for s in scenarios
            load = compute_load(uncertainties_at_ech, network, ts, s)
            cut_conso = model_container.slack_model.p_cut_conso[ts,s]

            prod = ( sum_injections(model_container.limitable_model, ts, s) +
                    sum_injections(model_container.imposable_model, ts, s) )
            cut_prod = model_container.limitable_model.p_capping[ts,s]

            model_container.eod_constraint[ts,s] = @constraint(model_container.model,
                        prod - cut_prod == load - cut_conso )
        end
    end
end
