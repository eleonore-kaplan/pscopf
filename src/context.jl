using Dates

struct Planning
    decider::String
    #PlanningFerme
    #PlanningProvisoire
end

mutable struct PSCOPFContext <: AbstractContext
    grid::Grid
    target_timepoints::Vector{Dates.DateTime}
    horizon_timepoints::Vector{Dates.DateTime}
    management_mode::ManagementMode
    #uncertainties
    #AssessmentUncertainties

    tso_planning::Planning
    market_planning::Planning
    current_ech::Dates.DateTime
    #still need to save the decision history, e.g. dict{ech->(planningTSO,PlanningMarket)} 
    #besoin d'info sur les états des groupes 
end
function PSCOPFContext(grid::Grid, target_timepoints::Vector{Dates.DateTime}, horizon_timepoints::Vector{Dates.DateTime},
                    management_mode::ManagementMode, tso_planning::Planning, market_planning::Planning)
    return PSCOPFContext(grid, target_timepoints, horizon_timepoints, management_mode, tso_planning, market_planning, horizon_timepoints[1])
end

function set_current_ech!(context_p, ech)
    context_p.current_ech = ech
end

function get_current_ech(context_p)
    return context_p.current_ech
end

function get_last_tso_planning(context_p)
    return context_p.tso_planning
end

function get_last_market_planning(context_p)
    return context_p.market_planning
end
