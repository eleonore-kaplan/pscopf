using .Networks

using JuMP
using Dates

try
    using Xpress;
    global OPTIMIZER = Xpress.Optimizer
catch e_xpress
    if isa(e_xpress, ArgumentError)
        try
            using CPLEX;
            global OPTIMIZER = CPLEX.Optimizer
        catch e_cplex
            if isa(e_cplex, ArgumentError)
                using Cbc;
                global OPTIMIZER = Cbc.Optimizer
            else
                throw(e_cplex)
            end
        end
    else
        throw(e_xpress)
    end
end
println("USED OPTIMIZER: ", OPTIMIZER)

"""
Possible status values for a pscopf model container

    - pscopf_OPTIMAL : a solution that does not use slacks was retrieved
    - pscopf_INFEASIBLE : no solution was retrieved
    - pscopf_FEASIBLE : non-optimal solution was retrieved
    - pscopf_UNSOLVED : model is not solved yet
"""
@enum PSCOPFStatus begin
    pscopf_OPTIMAL
    pscopf_INFEASIBLE
    pscopf_FEASIBLE
    pscopf_HAS_SLACK
    pscopf_UNSOLVED
end


abstract type AbstractModelContainer end

abstract type AbstractGeneratorModel end
abstract type AbstractPilotableModel <: AbstractGeneratorModel end
abstract type AbstractLimitableModel <: AbstractGeneratorModel end

abstract type AbstractLoLModel end

abstract type AbstractObjectiveModel end

# TODO : use a proper struct for by scenario variables
# eg: UncertainValue{VariableRef}
# or maybe a similar other struct cause depending on "ech"
#    we either will need by scenario vars (eg. injection/commitment before DP/DMO for pilotables)
#    or we will need one variable (eg. injection at or after DP for pilotables)
# if need a firm value (at/after DP or DMO) call a link_scenarios(::AbstractModel, ::)
# which adds @constraint(model, by_scenario_vars[s] == firm_variable)
# or maybe no need to if we create a single variable for scenarios right from the beginning
# and have proper getters too get_var(::, s) -> scenario's var or missing
# and have proper getters too get_var(::) -> firm var or error

struct BilevelModelContainer{U,L,K} <: AbstractModelContainer
    model::Model
    upper::U
    lower::L
    kkt_model::K
end

# AbstractModelContainer
###########################

function get_model(model_container::AbstractModelContainer)::AbstractModel
    return model_container.model
end

function get_status(model_container_p::AbstractModelContainer)::PSCOPFStatus
    solver_status_l = termination_status(get_model(model_container_p))

    if solver_status_l == MOI.OPTIMIZE_NOT_CALLED
        return pscopf_UNSOLVED
    elseif solver_status_l == MOI.INFEASIBLE
        @error "model status is infeasible!"
        return pscopf_INFEASIBLE
    elseif solver_status_l == MOI.OPTIMAL
        if has_positive_slack(model_container_p)
            @warn "model solved optimally but slack variables were used!"
            return pscopf_HAS_SLACK
        else
            return pscopf_OPTIMAL
        end
    else
        @warn "solver termination status was not optimal : $(solver_status_l)"
        return pscopf_FEASIBLE
    end
end

function solve!(model::AbstractModel,
                problem_name="problem", out_folder=nothing,
                optimizer=OPTIMIZER)
    problem_name_l = replace(problem_name, ":"=>"_")
    set_optimizer(model, optimizer);

    if !isnothing(out_folder)
        mkpath(out_folder)
        model_file_l = joinpath(out_folder, problem_name_l*".lp")
        write_to_file(model, model_file_l)

        log_file_l = joinpath(out_folder, problem_name_l*".log")
    else
        log_file_l = devnull
    end

    redirect_to_file(log_file_l) do
        optimize!(model)
    end

    return model
end

function solve!(model_container::AbstractModelContainer, problem_name, out_path)
    model_l = get_model(model_container)

    @info problem_name
    solve!(model_l, problem_name, out_path)
    @info "pscopf model status: $(get_status(model_container))"
    @info "Termination status : $(termination_status(model_l))"
    @info "Objective value : $(objective_value(model_l))"

    return model_container
end

function get_p_injected(model_container, type::Networks.GeneratorType)
    if type == Networks.LIMITABLE
        return model_container.limitable_model.p_injected
    elseif type == Networks.PILOTABLE
        return model_container.pilotable_model.p_injected
    end
    return nothing
end

function has_positive_slack(model_container)::Bool
    error("unimplemented")
end

function requires_linking(firmness::DecisionFirmness, do_link::Bool=false)::Bool
    return do_link || (firmness in [DECIDED, TO_DECIDE])
end


# AbstractGeneratorModel
############################

function get_p_injected(generator_model::AbstractGeneratorModel)
    return generator_model.p_injected
end

function has_injections(generator_model::AbstractGeneratorModel)
    return hasproperty(generator_model, :p_injected)
end

function add_unit_commitment_vars!(model::AbstractModel, pilotable_model::AbstractPilotableModel,
                                    pilotables_list, target_timepoints, scenarios)
    for gen in pilotables_list
        if Networks.needs_commitment(gen)
            gen_id = Networks.get_id(gen)
            for ts in target_timepoints
                for s in scenarios
                    add_b_on_start!(pilotable_model, model,
                                    gen_id, ts, s)
                end
            end
        end
    end
end

function add_injection_vars!(model::AbstractModel, generator_model::AbstractGeneratorModel,
                            generators_list::Vector{Networks.Generator}, target_timepoints, scenarios)
    for gen in generators_list
        gen_id = Networks.get_id(gen)
        for ts in target_timepoints
            for s in scenarios
                add_p_injected!(generator_model, model,
                                gen_id, ts, s)
            end
        end
    end
end

function add_p_injected!(generator_model::AbstractGeneratorModel, model::AbstractModel,
                        gen_id::String, ts::DateTime, s::String,
                        )::AbstractVariableRef
    name =  @sprintf("P_injected[%s,%s,%s]", gen_id, ts, s)
    var_l = get_p_injected(generator_model)[gen_id, ts, s] = @variable(model, base_name=name, lower_bound=0.)
    return var_l
end

function add_p_injected!(generator_model::AbstractGeneratorModel, model::AbstractModel,
                        gen_id::String, ts::DateTime, s::String,
                        p_max::Float64,
                        force_to_max::Bool
                        )::AbstractVariableRef
    name =  @sprintf("P_injected[%s,%s,%s]", gen_id, ts, s)

    if force_to_max
        generator_model.p_injected[gen_id, ts, s] = @variable(model, base_name=name,
                                                        lower_bound=p_max, upper_bound=p_max)
    else
        generator_model.p_injected[gen_id, ts, s] = @variable(model, base_name=name,
                                                        lower_bound=0., upper_bound=p_max)
    end

    return generator_model.p_injected[gen_id, ts, s]
end

function sum_injections(generator_model::AbstractGeneratorModel,
    ids::AbstractArray, ts::Dates.DateTime, s::String)::AffExpr
    error("TODO")
    for id in ids
        #...
    end
end
function sum_injections(generator_model::AbstractGeneratorModel,
                        ts::Dates.DateTime, s::String)
    sum_l = 0.
    for ((_,ts_l,s_l), var_l) in get_p_injected(generator_model)
        if (ts_l,s_l) == (ts, s)
            sum_l += var_l
        end
    end
    return sum_l
end

function add_p_delta!(generator_model::AbstractGeneratorModel, model::Model,
                        gen_id::String, ts::DateTime, s::String,
                        p_reference::Float64
                        )::VariableRef
    @assert(has_injections(generator_model))
    p_injected = get_p_injected(generator_model)
    deltas = generator_model.delta_p

    name =  @sprintf("Delta_p[%s,%s,%s]", gen_id, ts, s)
    deltas[gen_id, ts, s] = @variable(model, base_name=name, lower_bound=0.)
    @constraint(model, deltas[gen_id, ts, s] >= p_injected[gen_id, ts, s] - p_reference)
    @constraint(model, deltas[gen_id, ts, s] >= p_reference - p_injected[gen_id, ts, s])

    return generator_model.delta_p[gen_id, ts, s]
end

function add_delta_p_vars!(model::AbstractModel, generator_model::AbstractGeneratorModel,
                        generators_list::Vector{Networks.Generator}, target_timepoints, scenarios,
                        reference_market_schedule::Schedule)
    for gen in generators_list
        gen_id = Networks.get_id(gen)
        for ts in target_timepoints
            for s in scenarios
                p_ref = get_prod_value(reference_market_schedule, gen_id, ts, s)
                p_ref = ismissing(p_ref) ? 0. : p_ref
                add_p_delta!(generator_model, model, gen_id, ts, s, p_ref)
            end
        end
    end
end


# AbstractLimitableModel
############################

function add_limitables_vars!(model_container::AbstractModelContainer, target_timepoints, scenarios,
                            limitables_list::Union{Missing,Vector{Networks.Generator}}=missing,
                            reference_market_schedule::Union{Missing,Schedule}=missing;
                            global_capping_vars::Bool=false, injection_vars::Bool=false, limit_vars::Bool=false, delta_vars::Bool=false
                            )
    model = get_model(model_container)
    limitable_model = model_container.limitable_model

    if injection_vars
        add_injection_vars!(model, limitable_model,
                          limitables_list, target_timepoints, scenarios)

        if delta_vars
            if ismissing(reference_market_schedule)
                error("reference_market_schedule argument is mandatory to define delta variables!")
            end
            add_delta_p_vars!(model, limitable_model,
                            limitables_list, target_timepoints, scenarios, reference_market_schedule)
        end
    end

    if limit_vars
        add_limitation_vars!(model, limitable_model, limitables_list, target_timepoints, scenarios)
    end

    if global_capping_vars
        add_global_capping_vars!(model, limitable_model, target_timepoints, scenarios)
    end

end

function get_global_capping(limitable_model::AbstractLimitableModel)
    return limitable_model.p_global_capping
end

function add_global_capping_vars!(model::AbstractModel, limitable_model::AbstractLimitableModel, target_timepoints, scenarios)
    for ts in target_timepoints
        for s in scenarios
            name =  @sprintf("P_global_capping[%s,%s]", ts, s)
            get_global_capping(limitable_model)[ts, s] = @variable(model, base_name=name, lower_bound=0.)
        end
    end
end

function sum_capping(limitable_model::AbstractLimitableModel, ts,s)
    return get_global_capping(limitable_model)[ts,s]
end
function sum_capping(limitable_model::AbstractLimitableModel, ts, s, ::Networks.Network)
    return get_global_capping(limitable_model)[ts,s]
end

function global_capping_constraints!(model::AbstractModel,
                                    limitable_model::AbstractLimitableModel, limitables_list_l,
                                    target_timepoints, scenarios,
                                    uncertainties_at_ech::UncertaintiesAtEch;
                                    min_cap::SortedDict{Tuple{DateTime,String},V}=SortedDict{Tuple{DateTime,String},Float64}(),
                                    tso_actions::TSOActions=TSOActions()) where V <: Union{AbstractVariableRef,Float64}
    global_capping_vars = get_global_capping(limitable_model)
    for ts in target_timepoints
        for s in scenarios
            prod_capacity = compute_prod(uncertainties_at_ech, limitables_list_l, ts, s)
            c_name = @sprintf("c_max_global_capped[%s,%s]",ts,s)
            @constraint(model, global_capping_vars[ts, s] <= prod_capacity , base_name = c_name)

            limitations_capped = compute_capped(uncertainties_at_ech, get_limitations(tso_actions), limitables_list_l, ts, s)
            c_name = @sprintf("c_global_capped_by_limitations[%s,%s]",ts,s)
            @constraint(model, global_capping_vars[ts, s] >= limitations_capped , base_name = c_name)

            if haskey(min_cap, (ts,s))
                c_name = @sprintf("c_min_global_capping[%s,%s]",ts,s)
                @constraint(model, global_capping_vars[ts, s] >= min_cap[ts,s] , base_name = c_name)
            end
        end
    end
end

function add_limitation_vars!(model::AbstractModel,
                            limitable_model::AbstractLimitableModel,
                            limitables_list::Vector{Networks.Generator}, target_timepoints, scenarios)
    p_limit = limitable_model.p_limit
    b_is_limited = limitable_model.b_is_limited
    p_limit_x_is_limited = limitable_model.p_limit_x_is_limited

    for limitable_gen in limitables_list
        gen_id = Networks.get_id(limitable_gen)
        pmax = Networks.get_p_max(limitable_gen)
        for ts in target_timepoints
            for s in scenarios
                name =  @sprintf("P_limit[%s,%s,%s]", gen_id, ts, s)
                p_limit[gen_id, ts, s] = @variable(model, base_name=name, lower_bound=0., upper_bound=pmax)

                name =  @sprintf("B_is_limited[%s,%s,%s]", gen_id, ts, s)
                b_is_limited[gen_id, ts, s] = @variable(model, base_name=name, binary=true)

                name =  @sprintf("P_limit_x_is_limited[%s,%s,%s]", gen_id, ts, s)
                p_limit_x_is_limited[gen_id, ts, s] = add_prod_vars!(model,
                                                                    p_limit[gen_id, ts, s],
                                                                    b_is_limited[gen_id, ts, s],
                                                                    pmax,
                                                                    name
                                                                    )
            end
        end
    end
end

function bound_limit!(model::AbstractModel,
                    limitable_model::AbstractLimitableModel, limitables_list_l, target_timepoints, scenarios)
    for gen in limitables_list_l
        gen_id = Networks.get_id(gen)
        for ts in target_timepoints
            for s in scenarios
                p_enr = Networks.get_p_max(gen)
                c_name = @sprintf("c_limitable_max[%s,%s,%s]",gen_id,ts,s)
                @constraint(model, limitable_model.p_limit[gen_id,ts,s] <= p_enr, base_name=c_name)
            end
        end
    end
end
function inject_at_limit!(model::AbstractModel,
                        limitable_model::AbstractLimitableModel,
                        limitables_list_l, target_timepoints, scenarios,
                        uncertainties_at_ech::UncertaintiesAtEch)
    p_limit = limitable_model.p_limit
    b_is_limited = limitable_model.b_is_limited
    p_limit_x_is_limited = limitable_model.p_limit_x_is_limited
    for gen in limitables_list_l
        gen_id = Networks.get_id(gen)
        for ts in target_timepoints
            for s in scenarios
                injection_var = get_p_injected(limitable_model)[gen_id,ts,s]
                p_enr = min(Networks.get_p_max(gen), get_uncertainties(uncertainties_at_ech, gen_id, ts, s))
                #inj[g,ts,s] = min{p_limit[g,ts,s], uncertainties(g,ts,s), pmax(g)}
                name = @sprintf("pinj_lim_by_uncertainty[%s,%s,%s]",gen_id,ts,s)
                @constraint(model, injection_var <= p_enr, base_name = name)
                name = @sprintf("pinj_lim_by_limit[%s,%s,%s]",gen_id,ts,s)
                @constraint(model, injection_var <= p_limit[gen_id,ts,s], base_name = name)
                name = @sprintf("pinj_at_limit_or_uncertainty[%s,%s,%s]",gen_id,ts,s)
                @constraint(model, injection_var ==
                                (1-b_is_limited[gen_id, ts, s]) * p_enr + p_limit_x_is_limited[gen_id, ts, s],
                            base_name = name)
            end
        end
    end
end
function limitable_power_constraints!(model::AbstractModel,
                                    limitable_model::AbstractLimitableModel,
                                    limitables_list_l, target_timepoints, scenarios,
                                    firmness, uncertainties_at_ech::UncertaintiesAtEch;
                                    always_link_scenarios::Bool=false)
    bound_limit!(model,
                limitable_model, limitables_list_l, target_timepoints, scenarios)
    inject_at_limit!(model,
                    limitable_model, limitables_list_l, target_timepoints, scenarios, uncertainties_at_ech)

    for gen in limitables_list_l
        @assert(Networks.get_type(gen) == Networks.LIMITABLE)
        gen_id = Networks.get_id(gen)
        add_scenarios_linking_constraints!(model, gen,
                                        limitable_model.p_limit,
                                        target_timepoints, scenarios,
                                        get_power_level_firmness(firmness, gen_id),
                                        always_link_scenarios
                                        )
    end

end

function add_p_limit!(limitable_model::AbstractLimitableModel, model::AbstractModel,
                        gen_id::String, ts::Dates.DateTime,
                        scenarios::Vector{String},
                        pmax,
                        inject_uncertainties::InjectionUncertainties,
                        decision_firmness::DecisionFirmness, #by ts
                        always_link_scenarios=false
                        )
    b_is_limited = limitable_model.b_is_limited
    p_limit_x_is_limited = limitable_model.p_limit_x_is_limited
    p_limit = limitable_model.p_limit

    for s in scenarios
        name =  @sprintf("P_limit[%s,%s,%s]", gen_id, ts, s)
        p_limit[gen_id, ts, s] = @variable(model, base_name=name, lower_bound=0., upper_bound=pmax)

        injection_var = limitable_model.p_injected[gen_id, ts, s]

        name =  @sprintf("B_is_limited[%s,%s,%s]", gen_id, ts, s)
        b_is_limited[gen_id, ts, s] = @variable(model, base_name=name, binary=true)

        name =  @sprintf("P_limit_x_is_limited[%s,%s,%s]", gen_id, ts, s)
        p_limit_x_is_limited[gen_id, ts, s] = add_prod_vars!(model,
                                                            p_limit[gen_id, ts, s],
                                                            b_is_limited[gen_id, ts, s],
                                                            pmax,
                                                            name
                                                            )

        #inj[g,ts,s] = min{p_limit[g,ts,s], uncertainties(g,ts,s), pmax(g)}
        name = @sprintf("c1_pinj_lim[%s,%s,%s]",gen_id,ts,s)
        @constraint(model, injection_var <= p_limit[gen_id, ts, s], base_name = name)
        name = @sprintf("c2_pinj_lim[%s,%s,%s]",gen_id,ts,s)
        p_enr = min(get_uncertainties(inject_uncertainties, ts, s), pmax)
        @constraint(model, injection_var ==
                        (1-b_is_limited[gen_id, ts, s]) * p_enr + p_limit_x_is_limited[gen_id, ts, s],
                    base_name = name)
    end

    # NOTE : DECIDED here does not hold its meaning. FIRM is more expressive.
    #       p_limit can always be changed in the future horizons (it is not really decided)
    #DECIDED indicates that we are past the limitable's DP => need a common decision for all scenarios
    if requires_linking(decision_firmness, always_link_scenarios)
        link_scenarios!(model, p_limit, gen_id, ts, scenarios)
    end

    return limitable_model, model
end

# AbstractPilotableModel
############################

function add_pilotables_vars!(model_container::AbstractModelContainer,
                            pilotables_list, target_timepoints, scenarios,
                            reference_market_schedule::Union{Schedule,Missing}=missing;
                            injection_vars::Bool=false, commitment_vars::Bool=false, delta_vars::Bool=false)
    model = get_model(model_container)
    if injection_vars
        add_injection_vars!(model, model_container.pilotable_model,
                            pilotables_list, target_timepoints, scenarios)

        if delta_vars
            if ismissing(reference_market_schedule)
                error("reference_market_schedule argument is mandatory to define delta variables!")
            end
            add_delta_p_vars!(model, model_container.pilotable_model,
                                pilotables_list, target_timepoints, scenarios, reference_market_schedule)
        end
    end

    if commitment_vars
            add_unit_commitment_vars!(model, model_container.pilotable_model,
                                    pilotables_list, target_timepoints, scenarios)
    end
end


function get_b_on(pilotable_model::AbstractPilotableModel)
    return pilotable_model.b_on
end
function get_b_start(pilotable_model::AbstractPilotableModel)
    return pilotable_model.b_start
end

function add_b_on_start!(pilotable_model::AbstractPilotableModel, model::AbstractModel,
                    gen_id::String, ts::DateTime, s::String,
                    )
    name =  @sprintf("B_on[%s,%s,%s]", gen_id, ts, s)
    get_b_on(pilotable_model)[gen_id, ts, s] = @variable(model, base_name=name, binary=true)
    name =  @sprintf("B_start[%s,%s,%s]", gen_id, ts, s)
    get_b_start(pilotable_model)[gen_id, ts, s] = @variable(model, base_name=name, binary=true)
end

function pilotable_power_constraints!(model::AbstractModel,
                                    pilotable_model::AbstractPilotableModel,
                                    pilotable_gen::Generator,
                                    target_timepoints,
                                    scenarios,
                                    gen_commitment_firmness::Union{Missing, SortedDict{Dates.DateTime, PSCOPF.DecisionFirmness}},
                                    gen_power_level_firmness::SortedDict{Dates.DateTime, PSCOPF.DecisionFirmness},
                                    gen_schedule::GeneratorSchedule,
                                    always_link_scenarios::Bool
                                    )
    @assert(Networks.get_type(pilotable_gen) == Networks.PILOTABLE)

    gen_id = Networks.get_id(pilotable_gen)
    p_max = Networks.get_p_max(pilotable_gen)
    for ts in target_timepoints
        for s in scenarios
            c_name = @sprintf("c_generator_p_max[%s,%s,%s]",gen_id,ts,s)
            @constraint(model, get_p_injected(pilotable_model)[gen_id,ts,s] <= p_max, base_name=c_name)
        end
    end

    add_scenarios_linking_constraints!(model, pilotable_gen,
                                        get_p_injected(pilotable_model),
                                        target_timepoints, scenarios,
                                        gen_power_level_firmness,
                                        always_link_scenarios
                                        )

    add_power_level_decided_constraints!(model,
                                        pilotable_gen,
                                        get_p_injected(pilotable_model),
                                        target_timepoints,
                                        scenarios,
                                        gen_commitment_firmness,
                                        gen_power_level_firmness,
                                        gen_schedule,
                                        )
end
function pilotable_power_constraints!(model::AbstractModel,
                                    pilotable_model::AbstractPilotableModel,
                                    pilotables_list_l, target_timepoints, scenarios,
                                    firmness::Firmness,
                                    reference_schedule::Schedule;
                                    always_link_scenarios::Bool=false)
    for pilotable_gen in pilotables_list_l
        gen_id = Networks.get_id(pilotable_gen)
        pilotable_power_constraints!(model,
                        pilotable_model,
                        pilotable_gen,
                        target_timepoints,
                        scenarios,
                        get_commitment_firmness(firmness, gen_id), #can be missing for pilotables with pmin=0
                        get_power_level_firmness(firmness, gen_id),
                        get_sub_schedule(reference_schedule, gen_id),
                        always_link_scenarios
                        )
    end
end

function unit_commitment_constraints!(model::AbstractModel,
                                pilotable_model::AbstractPilotableModel, pilotables_list_l,  target_timepoints, scenarios,
                                firmness, reference_schedule, generators_initial_state;
                                always_link_scenarios::Bool=false)
    for pilotable_gen in pilotables_list_l
        if !Networks.needs_commitment(pilotable_gen)
            continue
        end
        gen_id = Networks.get_id(pilotable_gen)

        add_commitment_constraints!(model,
                                    get_b_on(pilotable_model),
                                    get_b_start(pilotable_model),
                                    gen_id::String,
                                    target_timepoints,
                                    scenarios,
                                    get_initial_state(generators_initial_state, pilotable_gen))

        add_scenarios_linking_constraints!(model,
                                        pilotable_gen, get_b_on(pilotable_model),
                                        target_timepoints, scenarios,
                                        get_commitment_firmness(firmness, gen_id),
                                        always_link_scenarios
                                        )
        #linking b_on => linking b_start
        add_commitment_sequencing_constraints!(model, pilotable_gen,
                                            get_b_on(pilotable_model),
                                            get_b_start(pilotable_model),
                                            target_timepoints, scenarios,
                                            get_commitment_firmness(firmness, gen_id),
                                            get_sub_schedule(reference_schedule, gen_id)
                                            )

        if has_injections(pilotable_model)
            link_injection_to_commitment!(model,
                                        get_p_injected(pilotable_model), get_b_on(pilotable_model),
                                        gen_id, target_timepoints, scenarios,
                                        Networks.get_p_min(pilotable_gen), Networks.get_p_max(pilotable_gen))
        end
    end
end

function link_injection_to_commitment!(model::AbstractModel,
                                        p_injected_vars, b_on_vars,
                                        gen_id::String, target_timepoints, scenarios,
                                        p_min::Float64, p_max::Float64)
    for ts in target_timepoints
        for s in scenarios
            @constraint(model, p_injected_vars[gen_id, ts, s] <= p_max * b_on_vars[gen_id, ts, s]);
            @constraint(model, p_injected_vars[gen_id, ts, s] >= p_min * b_on_vars[gen_id, ts, s]);
        end
    end
end

function add_commitment_constraints!(model::AbstractModel,
                                    b_on_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                    b_start_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                    gen_id::String,
                                    target_timepoints::Vector{Dates.DateTime},
                                    scenarios::Vector{String},
                                    generator_initial_state::GeneratorState)
    for s in scenarios
        for (ts_index, ts) in enumerate(target_timepoints)
            preceding_on = (ts_index > 1) ? b_on_vars[gen_id, target_timepoints[ts_index-1], s] : float(generator_initial_state)
            @constraint(model, b_start_vars[gen_id, ts, s] <= b_on_vars[gen_id, ts, s])
            @constraint(model, b_start_vars[gen_id, ts, s] <= 1 - preceding_on)
            @constraint(model, b_start_vars[gen_id, ts, s] >= b_on_vars[gen_id, ts, s] - preceding_on)
        end
    end
    return model
end
function add_commitment!(pilotable_model::AbstractPilotableModel, model::AbstractModel,
                        generator::Networks.Generator,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        generator_initial_state::GeneratorState
                        )
    p_injected_vars = pilotable_model.p_injected
    b_on_vars = pilotable_model.b_on
    b_start_vars = pilotable_model.b_start

    gen_id = Networks.get_id(generator)
    p_max = Networks.get_p_max(generator)
    p_min = Networks.get_p_min(generator)
    for s in scenarios
        for ts in target_timepoints
            name =  @sprintf("B_on[%s,%s,%s]", gen_id, ts, s)
            b_on_vars[gen_id, ts, s] = @variable(model, base_name=name, binary=true)
            name =  @sprintf("B_start[%s,%s,%s]", gen_id, ts, s)
            b_start_vars[gen_id, ts, s] = @variable(model, base_name=name, binary=true)

            # pmin < P_injected < pmax OR = 0
            @constraint(model, p_injected_vars[gen_id, ts, s] <= p_max * b_on_vars[gen_id, ts, s]);
            @constraint(model, p_injected_vars[gen_id, ts, s] >= p_min * b_on_vars[gen_id, ts, s]);
        end
    end

    #commitment_constraints : link b_start and b_on
    add_commitment_constraints!(model,
                                b_on_vars, b_start_vars,
                                gen_id, target_timepoints, scenarios, generator_initial_state)

    return pilotable_model, model
end


function respect_impositions_constraints!(model::AbstractModel,
                                        pilotable_model::AbstractPilotableModel, pilotables_list_l,  target_timepoints, scenarios,
                                        tso_actions::TSOActions)
    p_injected_vars = get_p_injected(pilotable_model)
    for pilotable_gen in pilotables_list_l
        gen_id = Networks.get_id(pilotable_gen)
        for ts in target_timepoints
            for s in scenarios
                imposition_bounds = get_imposition(tso_actions, gen_id, ts, s)
                if !ismissing(imposition_bounds)
                    c_name = @sprintf("c_min_imposition[%s,%s,%s]",gen_id,ts,s)
                    @constraint(model, imposition_bounds[1] <= p_injected_vars[gen_id,ts,s], base_name=c_name)
                    c_name = @sprintf("c_max_imposition[%s,%s,%s]",gen_id,ts,s)
                    @constraint(model, p_injected_vars[gen_id,ts,s] <= imposition_bounds[2], base_name=c_name)
                    @debug @sprintf("impositions constraints [%s,%s,%s] : [%s,%s]",
                                    gen_id, ts, s, imposition_bounds[1], imposition_bounds[2])
                end
            end
        end
    end
end

# Objective
##################

function add_pilotable_start_cost!(obj_component::AffExpr,
                                b_start::AbstractDict{T,V}, network, gratis_starts) where T <: Tuple where V <: VariableRef
    for ((gen_id,ts,_), b_start_var) in b_start
        if (gen_id,ts) in gratis_starts
            @debug(@sprintf("ignore starting cost of %s at %s", gen_id, ts))
            continue
        end
        generator = Networks.get_generator(network, gen_id)
        gen_start_cost = Networks.get_start_cost(generator)
        add_to_expression!(obj_component,
                            b_start_var * gen_start_cost)
    end

    return obj_component
end

function add_prop_cost!(obj_component::AffExpr,
                                p_injected::AbstractDict{T,V}, network)  where T <: Tuple where V <: VariableRef
    for ((gen_id,_,_), p_injected_var) in p_injected
        generator = Networks.get_generator(network, gen_id)
        gen_prop_cost = Networks.get_prop_cost(generator)
        add_to_expression!(obj_component,
                            p_injected_var * gen_prop_cost)
    end

    return obj_component
end

function add_coeffxsum_cost!(obj_component::AffExpr,
                            vars_dict::AbstractDict{T,V}, coeff::Float64)  where T where V <: VariableRef
    for (_, var_l) in vars_dict
        add_to_expression!(obj_component, coeff * var_l)
    end

    return obj_component
end


# AbstractLoLModel
############################
function add_lol_vars!(model_container::AbstractModelContainer, target_timepoints, scenarios,
                    buses_list::Union{Missing,Vector{Networks.Bus}}=missing;
                    global_lol_vars::Bool=false, local_lol_vars::Bool=false)
    model = get_model(model_container)
    lol_model = model_container.lol_model

    if global_lol_vars
        add_global_lol_vars!(model, lol_model, target_timepoints, scenarios)
    end

    if local_lol_vars
        add_local_lol_vars!(model, lol_model, buses_list, target_timepoints, scenarios)
    end
end

function get_global_lol(lol_model::AbstractLoLModel)
    return lol_model.p_global_loss_of_load
end

function add_global_lol_vars!(model::AbstractModel, lol_model::AbstractLoLModel, target_timepoints, scenarios)
    for ts in target_timepoints
        for s in scenarios
            name =  @sprintf("P_global_lol[%s,%s]", ts, s)
            get_global_lol(lol_model)[ts, s] = @variable(model, base_name=name, lower_bound=0.)
        end
    end
end

function sum_lol(lol_model::AbstractLoLModel, ts, s, network=nothing)
    return get_global_lol(lol_model)[ts,s]
end

function global_lol_constraints!(model::AbstractModel,
                            lol_model::AbstractLoLModel, buses_list, target_timepoints, scenarios,
                            uncertainties_at_ech::UncertaintiesAtEch,
                            min_lol::SortedDict{Tuple{DateTime,String},V}=SortedDict{Tuple{DateTime,String},Float64}()
                            ) where V <: Union{AbstractVariableRef,Float64}
    global_lol_vars = get_global_lol(lol_model)
    for ts in target_timepoints
        for s in scenarios
            max_load = compute_load(uncertainties_at_ech, buses_list, ts, s)
            c_name = @sprintf("c_ub_global_lol[%s,%s]",ts,s)
            @constraint(model, global_lol_vars[ts, s] <= max_load , base_name = c_name)

            if haskey(min_lol, (ts,s))
                c_name = @sprintf("c_min_global_lol[%s,%s]",ts,s)
                @constraint(model, global_lol_vars[ts, s] >= min_lol[ts,s] , base_name = c_name)
            end
        end
    end
end

function get_local_lol(lol_model::AbstractLoLModel)
    return lol_model.p_loss_of_load
end

function add_local_lol_vars!(model::AbstractModel, lol_model::AbstractLoLModel,
                            buses_list::Vector{Networks.Bus}, target_timepoints, scenarios)
    for bus in buses_list
        bus_id = Networks.get_id(bus)
        for ts in target_timepoints
            for s in scenarios
                name =  @sprintf("P_local_lol[%s,%s,%s]", bus_id, ts, s)
                get_local_lol(lol_model)[bus_id, ts, s] = @variable(model, base_name=name, lower_bound=0.)
            end
        end
    end
end

function local_lol_constraints!(model::AbstractModel, lol_model::AbstractLoLModel,
                            buses_list, target_timepoints, scenarios, uncertainties_at_ech)
    local_lol_vars = get_local_lol(lol_model)
    for bus in buses_list
        bus_id = Networks.get_id(bus)
        for ts in target_timepoints
            for s in scenarios
                bus_load = get_uncertainties(uncertainties_at_ech, bus_id, ts, s)
                c_name = @sprintf("c_ub_local_lol[%s,%s,%s]",bus_id,ts,s)
                @constraint(model, local_lol_vars[bus_id, ts, s] <= bus_load , base_name = c_name)
            end
        end
    end
end

function has_positive_value(dict_vars::AbstractDict{T,V}) where T where V <: AbstractVariableRef
    return any(e -> value(e[2]) > 1e-09, dict_vars)
    #e.g. 1e-15 is supposed to be 0.
end

function add_loss_of_load_by_bus!(model::AbstractModel, p_loss_of_load,
                                buses,
                                target_timepoints::Vector{Dates.DateTime},
                                scenarios::Vector{String},
                                uncertainties_at_ech::UncertaintiesAtEch
                                )
    for ts in target_timepoints
        for s in scenarios
            for bus in buses
                bus_id = Networks.get_id(bus)
                name =  @sprintf("P_loss_of_load[%s,%s,%s]", bus_id, ts, s)
                load = get_uncertainties(uncertainties_at_ech, bus_id, ts, s)
                p_loss_of_load[bus_id, ts, s] = @variable(model, base_name=name,
                                                            lower_bound=0., upper_bound=load)
            end
        end
    end
    return p_loss_of_load
end

# Constraints
##################

function eod_constraints!(model::AbstractModel, eod_constraints::SortedDict{Tuple{Dates.DateTime,String}, ConstraintRef},
                        pilotable_model::AbstractPilotableModel,
                        limitable_model::AbstractLimitableModel,
                        lol_model::AbstractLoLModel,
                        target_timepoints, scenarios,
                        uncertainties_at_ech, network)
    for ts in target_timepoints
        for s in scenarios

            prod = AffExpr()
            prod += sum_injections(pilotable_model, ts, s)
            if has_injections(limitable_model)
                prod += sum_injections(limitable_model, ts, s)
            else
                prod += compute_prod(uncertainties_at_ech, network, ts, s)
                prod -= sum_capping(limitable_model, ts, s, network)
            end

            load = AffExpr()
            load += compute_load(uncertainties_at_ech, network, ts, s)
            load -= sum_lol(lol_model, ts, s, network)

            c_name = @sprintf("c_eod[%s,%s]",ts,s)
            eod_constraints[ts,s] = @constraint(model, prod == load , base_name = c_name)

        end
    end
end

function rso_constraints!(model::AbstractModel,
                          flows::SortedDict{Tuple{String,Dates.DateTime,String}, VariableRef},
                          rso_constraints::SortedDict{Tuple{String,Dates.DateTime,String}, ConstraintRef},
                        pilotable_model::AbstractPilotableModel,
                        limitable_model::AbstractLimitableModel,
                        lol_model::AbstractLoLModel,
                        target_timepoints, scenarios,
                        uncertainties_at_ech, network::Networks.Network)
    for branch in Networks.get_branches(network)
        branch_id = Networks.get_id(branch)
        flow_limit_l = Networks.get_limit(branch)
        for ts in target_timepoints
            for s in scenarios
                name =  @sprintf("Flow[%s,%s,%s]", branch_id, ts, s)
                flows[branch_id, ts, s] =
                    @variable(model, base_name=name, lower_bound=-flow_limit_l, upper_bound=flow_limit_l)

                flow_l = AffExpr()
                for bus in Networks.get_buses(network)
                    bus_id = Networks.get_id(bus)
                    ptdf = Networks.safeget_ptdf(network, branch_id, bus_id)

                    # + injections limitables
                    for gen in Networks.get_generators_of_type(bus, Networks.LIMITABLE)
                        gen_id = Networks.get_id(gen)
                        var_p_injected = get_p_injected(limitable_model)[gen_id, ts, s]
                        flow_l += ptdf * var_p_injected
                    end

                    # + injections pilotables
                    for gen in Networks.get_generators_of_type(bus, Networks.PILOTABLE)
                        gen_id = Networks.get_id(gen)
                        var_p_injected = get_p_injected(pilotable_model)[gen_id, ts, s]
                        flow_l += ptdf * var_p_injected
                    end

                    # - loads
                    flow_l -= ptdf * get_uncertainties(uncertainties_at_ech, bus_id, ts, s)

                    # + cutting loads ~ injections
                    flow_l += ptdf * get_local_lol(lol_model)[bus_id, ts, s]
                end
                rso_constraints[branch_id, ts, s] = @constraint(model, flows[branch_id, ts, s] == flow_l )
            end
        end
    end
end

# Utils
##################

function link_scenarios!(model::AbstractModel, vars::AbstractDict{Tuple{String,DateTime,String},V},
                        gen_id::String, ts::DateTime, scenarios::Vector{String};
                        name=nothing) where V<:AbstractVariableRef
    s1 = scenarios[1]
    for (s_index, s) in enumerate(scenarios)
        if s_index > 1
            cstr_l = @constraint(model, vars[gen_id, ts, s] == vars[gen_id, ts, s1]);
            if !isnothing(name)
                set_name(cstr_l, @sprintf("%s[%s,%s,%s]",name,gen_id,ts,s))
            end
        end
    end
    return model
end

function add_keep_off_constraint!(model::AbstractModel, b_on_vars, b_start_vars,
                                gen_id, ts, scenarios)
    for s in scenarios
        @constraint(model, b_on_vars[gen_id, ts, s] == 0)
        @constraint(model, b_start_vars[gen_id, ts, s] == 0)
    end
    return model
end

function add_commitment_sequencing_constraints!(model::AbstractModel,
                                            generator::Networks.Generator,
                                            b_on_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                            b_start_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                            target_timepoints::Vector{Dates.DateTime},
                                            scenarios::Vector{String},
                                            commitment_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                                            generator_reference_schedule::GeneratorSchedule
                                            )
    gen_id = Networks.get_id(generator)
    for ts in target_timepoints
        if commitment_firmness[ts] == DECIDED
            reference_on_val = safeget_commitment_value(generator_reference_schedule, ts)
            if reference_on_val == OFF
                add_keep_off_constraint!(model, b_on_vars, b_start_vars, gen_id, ts, scenarios)
            end
        end
    end

    return model
end

function freeze_vars!(model, p_injected_vars,
                        gen_id, ts, scenarios,
                        imposed_value::Float64;
                        name=nothing)
    for s in scenarios
        @assert( !has_upper_bound(p_injected_vars[gen_id, ts, s]) || (imposed_value <= upper_bound(p_injected_vars[gen_id, ts, s])) )
        @assert( !has_lower_bound(p_injected_vars[gen_id, ts, s]) || (imposed_value >= lower_bound(p_injected_vars[gen_id, ts, s])) )
        cstr_l = @constraint(model, p_injected_vars[gen_id, ts, s] == imposed_value)
        if !isnothing(name)
            set_name(cstr_l, @sprintf("%s[%s,%s,%s]",name,gen_id,ts,s))
        end
    end
end

function add_scenarios_linking_constraints!(model::AbstractModel,
                                                generator::Networks.Generator,
                                                vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                                target_timepoints::Vector{Dates.DateTime},
                                                scenarios::Vector{String},
                                                gen_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                                                always_link::Bool
                                                )
    gen_id = Networks.get_id(generator)
    for ts in target_timepoints
        if requires_linking(gen_firmness[ts], always_link)
            link_scenarios!(model, vars, gen_id, ts, scenarios)
        end
    end

    return model
end

function add_power_level_decided_constraints!(model::AbstractModel,
                                                generator::Networks.Generator,
                                                p_injected_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                                target_timepoints::Vector{Dates.DateTime},
                                                scenarios::Vector{String},
                                                commitment_firmness::Union{Missing,SortedDict{Dates.DateTime, DecisionFirmness}}, #by ts
                                                power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                                                generator_reference_schedule::GeneratorSchedule;
                                                cstr_prefix_name::String="decide_level"
                                                )
    @assert(Networks.get_type(generator) == Networks.PILOTABLE)

    gen_id = Networks.get_id(generator)
    for ts in target_timepoints
        ref_commitment = missing
        if (!ismissing(commitment_firmness) && (commitment_firmness[ts] == DECIDED))
            ref_commitment = get_commitment_value(generator_reference_schedule, ts)
        end

        for s in scenarios
            if !ismissing(ref_commitment) && (ref_commitment == OFF)
                c_name = @sprintf("c_decided_level_off[%s,%s,%s]",gen_id,ts,s)
                @constraint(model, p_injected_vars[gen_id,ts,s] == 0., base_name=c_name)
            elseif power_level_firmness[ts]==DECIDED
                scheduled_prod = safeget_prod_value(generator_reference_schedule,ts)
                @debug @sprintf("imposed decided level[%s,%s,%s] : %s", gen_id, ts, s, scheduled_prod)
                c_name = @sprintf("c_%s[%s,%s,%s]",cstr_prefix_name,gen_id,ts,s)
                @constraint(model, p_injected_vars[gen_id,ts,s] == scheduled_prod, base_name=c_name)
            end
        end
    end

    return model
end

"""
look at tso_actions commitment
    if unit is off, impose a level of 0.
If past DP, impose reference scheduled prod
else, impose bounds for production level
"""
function add_power_level_sequencing_constraints!(model::AbstractModel,
                                                generator::Networks.Generator,
                                                p_injected_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                                target_timepoints::Vector{Dates.DateTime},
                                                scenarios::Vector{String},
                                                power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                                                generator_reference_schedule::GeneratorSchedule,
                                                tso_actions::TSOActions=TSOActions()
                                                )
    @assert(Networks.get_type(generator) == Networks.PILOTABLE)

    gen_id = Networks.get_id(generator)
    for ts in target_timepoints
        ref_commitment = get_commitment_value(generator_reference_schedule, ts)

        for s in scenarios
            imposition_bounds = missing

            tso_action_impositions = get_imposition(tso_actions, gen_id, ts, s)
            @assert(ismissing(tso_action_impositions)
                    || (tso_action_impositions[1] <= tso_action_impositions[2]))
            if !ismissing(ref_commitment) && (ref_commitment == OFF)
                if !ismissing(tso_action_impositions) && (tso_action_impositions[1] > 1e-09)
                    msg = @sprintf("(%s,%s) : minimum imposition %f and reference unit commitment %s are incompatible!",
                                    gen_id,ts,tso_action_impositions[2],ref_commitment)
                    throw(error(msg))
                end
                imposition_bounds = (0., 0.)
            elseif !ismissing(tso_action_impositions)
                imposition_bounds = (tso_action_impositions[1], tso_action_impositions[2])
            end

            if power_level_firmness[ts]==DECIDED
            # => does not allow unit shutdown after DP cause level is forced
                scheduled_prod = safeget_prod_value(generator_reference_schedule,ts)
                @debug @sprintf("imposed decided level[%s,%s,%s] : %s", gen_id, ts, s, scheduled_prod)
                @assert( ismissing(imposition_bounds) ||
                        (imposition_bounds[1] <= scheduled_prod <= imposition_bounds[2]) )
                c_name = @sprintf("c_decided_level[%s,%s,%s]",gen_id,ts,s)
                @constraint(model, p_injected_vars[gen_id,ts,s] == scheduled_prod, base_name=c_name)
            elseif !ismissing(imposition_bounds)
                c_name = @sprintf("c_min_imposition[%s,%s,%s]",gen_id,ts,s)
                @constraint(model, imposition_bounds[1] <= p_injected_vars[gen_id,ts,s], base_name=c_name)
                c_name = @sprintf("c_max_imposition[%s,%s,%s]",gen_id,ts,s)
                @constraint(model, p_injected_vars[gen_id,ts,s] <= imposition_bounds[2], base_name=c_name)
                @debug @sprintf("impositions constraints [%s,%s,%s] : [%s,%s]",
                                gen_id, ts, s, imposition_bounds[1], imposition_bounds[2])
            end
        end
    end

    return model
end


"""
    add_prod_vars!
adds to the model and returns a variable that represents the product expression (noted var_a_x_b):
   var_a * var_b where var_b is a binary variable, and var_a is a positive real variable bound by M
The following constraints are added to the model :
    var_a_x_b <= var_a
    var_a_x_b <= M * var_b
    M*(1 - var_b) + var_a_x_b >= var_a
"""
function add_prod_vars!(model::AbstractModel,
                        var_a::AbstractVariableRef,
                        var_binary::AbstractVariableRef,
                        M,
                        name
                        )::AbstractVariableRef
    if !is_binary(var_binary)
        throw(error("variable var_binary needs to be binary to express the product!"))
    end
    if lower_bound(var_a) < 0
        throw(error("variable var_a needs to be positive to express the product!"))
    end

    expr_var_a::AffExpr = var_a
    var_a_x_b = add_prod_expr_x_b!(model, expr_var_a, var_binary, M, name)

    return var_a_x_b
end

function add_prod_expr_x_b!(model::AbstractModel,
                        expr_a::AffExpr,
                        var_binary::AbstractVariableRef,
                        M,
                        name
                        )::AbstractVariableRef
    if !is_binary(var_binary)
        throw(error("variable var_binary needs to be binary to express the product!"))
    end
    if compute_lb(expr_a, -1) < 0
        c_name = @sprintf("c0_%s",name)
        @constraint(model, expr_a >= 0., base_name=c_name)
    end

    var_expra_x_b = @variable(model, base_name=name, lower_bound=0., upper_bound=M)
    c_name = @sprintf("c1_%s",name)
    @constraint(model, var_expra_x_b <= expr_a, base_name=c_name)
    c_name = @sprintf("c2_%s",name)
    @constraint(model, var_expra_x_b <= M * var_binary, base_name=c_name)
    c_name = @sprintf("c3_%s",name)
    @constraint(model, M*(1-var_binary) + var_expra_x_b >= expr_a, base_name=c_name)

    return var_expra_x_b
end

function formulate_complementarity_constraints!(model::Model,
                                                kkt_var::VariableRef, pos_cstr_expr, b_indicator, ub_kkt, ub_cstr)
    # complementarity constraints are supposed for constraints like : g(x) <= 0 => the duals should be positive
    #model should already have the constraints -pos_cstr_expr <= 0 and kkt_var >=0
    # reformulation adds the following constraints :
    # kkt_var <= M1 * b_indicator
    # -g(x) <= M2 * (1-b_indicator)
    @assert( lower_bound(kkt_var) >= 0 )

    name = "c1_complementarity_" * JuMP.name(kkt_var)
    @constraint(model, kkt_var <= ub_kkt*b_indicator, base_name=name)
    name = "c2_complementarity_" * JuMP.name(kkt_var)
    @constraint(model, pos_cstr_expr <= ub_cstr * (1-b_indicator), base_name=name)
    #This constraints should have already been added in primal-feasibility constraints : g_i(x)<=0
    name = "c3_complementarity_" * JuMP.name(kkt_var)
    @constraint(model, pos_cstr_expr >= 0, base_name=name)
end

function compute_ub(expr::AffExpr, big_m=nothing)
    expr_ub = expr.constant
    for (coeff, var) in linear_terms(expr)
        if coeff == 0
            continue
        elseif coeff > 0 && has_upper_bound(var)
            expr_ub += coeff * upper_bound(var)
        elseif coeff < 0 && has_lower_bound(var)
            expr_ub += coeff * lower_bound(var)
        else
            expr_ub = big_m
            break;
        end
    end

    if isnothing(expr_ub)
        error("need to specify bound for expression $(expr)")
    end

    return expr_ub
end

function compute_lb(expr::AffExpr, default_lb=nothing)
    expr_ub = expr.constant
    for (coeff, var) in linear_terms(expr)
        if coeff == 0
            continue
        elseif coeff > 0 && has_lower_bound(var)
            expr_ub += coeff * lower_bound(var)
        elseif coeff < 0 && has_upper_bound(var)
            expr_ub += coeff * upper_bound(var)
        else
            expr_ub = default_lb
            break;
        end
    end

    if isnothing(expr_ub)
        error("need to specify bound for expression $(expr)")
    end

    return expr_ub
end

