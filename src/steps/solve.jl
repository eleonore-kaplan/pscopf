function tso_solve!(model_container::AbstractModelContainer,
                solve_fct::Base.Callable, configs::AbstractRunnableConfigs,
                Uncertainties_at_ech::UncertaintiesAtEch, network::Networks.Network,
                dynamic_solving::Bool)
    if dynamic_solving
        iterative_solve_on_rso_constraints()
    else
        add_rso_flows_exprs!(model_container,
                            get_rso_combinations(model_container),
                            Uncertainties_at_ech,
                            network)
        add_rso_constraints!(model_container,
                            get_rso_combinations(model_container),
                            network)
        solve_fct(model_container, configs)
    end
end

function iterative_solve_on_rso_constraints()
    error("unimplemented!")
end

