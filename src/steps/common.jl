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

function solve!(model_container::AbstractModelContainer,
                problem_name="problem", out_folder=nothing,
                optimizer=OPTIMIZER)
    problem_name_l = replace(problem_name, ":"=>"_")
    model_l = get_model(model_container)
    set_optimizer(model_l, optimizer);

    if !isnothing(out_folder)
        mkpath(out_folder)
        model_file_l = joinpath(out_folder, problem_name_l*".lp")
        write_to_file(model_l, model_file_l)

        log_file_l = joinpath(out_folder, problem_name_l*".log")
    else
        log_file_l = devnull
    end

    redirect_to_file(log_file_l) do
        optimize!(model_l)
    end
end






abstract type AbstractGeneratorModel end
abstract type AbstractImposableModel <: AbstractGeneratorModel end
abstract type AbstractLimitableModel <: AbstractGeneratorModel end

abstract type AbstractObjectiveModel end
