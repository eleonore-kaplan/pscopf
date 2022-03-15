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
    pscopf_UNSOLVED
end


abstract type AbstractModelContainer end

function get_model(model_container::AbstractModelContainer)::Model
    return model_container.model
end

function get_status(model_container_p::AbstractModelContainer)::PSCOPFStatus
    solver_status_l = termination_status(get_model(model_container_p))

    if solver_status_l == OPTIMIZE_NOT_CALLED
        return pscopf_UNSOLVED
    elseif solver_status_l == INFEASIBLE
        @error "model status is infeasible!"
        return pscopf_INFEASIBLE
    elseif solver_status_l == OPTIMAL
        return pscopf_OPTIMAL
    else
        @warn "solver termination status was not optimal : $(solver_status_l)"
        return pscopf_FEASIBLE
    end
end

function solve!(model::Model,
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
end


abstract type AbstractGeneratorModel end
abstract type AbstractImposableModel <: AbstractGeneratorModel end
abstract type AbstractLimitableModel <: AbstractGeneratorModel end

abstract type AbstractSlackModel end

abstract type AbstractObjectiveModel end


# AbstractGeneratorModel
############################

function add_p_injected!(generator_model::AbstractGeneratorModel, model::Model,
                        gen_id::String, ts::DateTime, s::String,
                        p_max::Float64,
                        force_to_max::Bool
                        )
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
                        ts::Dates.DateTime, s::String)::AffExpr
    sum_l = AffExpr(0)
    for ((_,ts_l,s_l), var_l) in generator_model.p_injected
        if (ts_l,s_l) == (ts, s)
            sum_l += var_l
        end
    end
    return sum_l
end

# AbstractImposableModel
############################

function add_commitment!(imposable_model::AbstractImposableModel, model::Model,
                        generator::Networks.Generator,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        generator_initial_state::GeneratorState
                        )
    p_injected_vars = imposable_model.p_injected
    b_on_vars = imposable_model.b_on
    b_start_vars = imposable_model.b_start

    gen_id = Networks.get_id(generator)
    p_max = Networks.get_p_max(generator)
    p_min = Networks.get_p_min(generator)
    for s in scenarios
        for (ts_index, ts) in enumerate(target_timepoints)
            name =  @sprintf("B_on[%s,%s,%s]", gen_id, ts, s)
            b_on_vars[gen_id, ts, s] = @variable(model, base_name=name, binary=true)
            name =  @sprintf("B_start[%s,%s,%s]", gen_id, ts, s)
            b_start_vars[gen_id, ts, s] = @variable(model, base_name=name, binary=true)

            # pmin < P_injected < pmax OR = 0
            @constraint(model, p_injected_vars[gen_id, ts, s] <= p_max * b_on_vars[gen_id, ts, s]);
            @constraint(model, p_injected_vars[gen_id, ts, s] >= p_min * b_on_vars[gen_id, ts, s]);

            #commitment_constraints
            preceding_on = (ts_index > 1) ? b_on_vars[gen_id, target_timepoints[ts_index-1], s] : float(generator_initial_state)
            @constraint(model, b_start_vars[gen_id, ts, s] <= b_on_vars[gen_id, ts, s])
            @constraint(model, b_start_vars[gen_id, ts, s] <= 1 - preceding_on)
            @constraint(model, b_start_vars[gen_id, ts, s] >= b_on_vars[gen_id, ts, s] - preceding_on)
        end
    end

    return imposable_model, model
end

# Utils
##################

function link_scenarios!(model::Model, vars::AbstractDict{Tuple{String,DateTime,String},VariableRef},
                        gen_id::String, ts::DateTime, scenarios::Vector{String})
    s1 = scenarios[1]
    for (s_index, s) in enumerate(scenarios)
        if s_index > 1
            @constraint(model, vars[gen_id, ts, s] == vars[gen_id, ts, s1]);
        end
    end
    return model
end

function add_commitment_firmness_constraints!(model::Model,
                                            generator::Networks.Generator,
                                            b_on_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                            target_timepoints::Vector{Dates.DateTime},
                                            scenarios::Vector{String},
                                            commitment_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                                            generator_reference_schedule::GeneratorSchedule
                                            )
    gen_id = Networks.get_id(generator)
    for ts in target_timepoints
        if commitment_firmness[ts] in [DECIDED, TO_DECIDE]
            link_scenarios!(model, b_on_vars, gen_id, ts, scenarios)
        end

        if commitment_firmness[ts] == DECIDED
            val = float(safeget_commitment_value(generator_reference_schedule, ts))
            for s in scenarios
                @assert( !has_upper_bound(b_on_vars[gen_id, ts, s]) || (val <= upper_bound(b_on_vars[gen_id, ts, s])) )
                @constraint(model, b_on_vars[gen_id, ts, s] == val)
            end
        end
    end

    return model
end

function add_power_level_firmness_constraints!(model::Model,
                                                generator::Networks.Generator,
                                                p_injected_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                                target_timepoints::Vector{Dates.DateTime},
                                                scenarios::Vector{String},
                                                power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                                                generator_reference_schedule::GeneratorSchedule
                                                )
    gen_id = Networks.get_id(generator)
    for ts in target_timepoints
        if power_level_firmness[ts] in [DECIDED, TO_DECIDE]
            link_scenarios!(model, p_injected_vars, gen_id, ts, scenarios)
        end

        if power_level_firmness[ts] == DECIDED
            val = safeget_prod_value(generator_reference_schedule,ts)
            for s in scenarios
                @assert( !has_upper_bound(p_injected_vars[gen_id, ts, s]) || (val <= upper_bound(p_injected_vars[gen_id, ts, s])) )
                @constraint(model, p_injected_vars[gen_id, ts, s] == val)
            end
        end
    end

    return model
end
