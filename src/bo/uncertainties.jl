#TODO
using Dates

"""
    UncertaintyDistribution

describes the uncertainty distribution of an injection (load or renewable)
We consider `ts` as the target timepoint at which the realisation will have place,
and `ech` is the observation point.
The farthest we are from ts, the greater is the uncertainty: we assume an increase  by a ratio of `time_factor` for each hour. 
i.e.: factor_l = max{ 0, ( ts - ech )/1h } * time_factor
adjusted_sigma = factor_l * sigma
random_injection = mu * (1 + rand(Normal(0, adjusted_sigma)) )

# Arguments
    - `min_value::Float64` : minimum value that can be assigned to the injection
    - `max_value::Float64` : maxiimum value that can be assigned to the injection
    - `mu::Float64` : average injection value
    - `sigma::Float64` : base sigma value to be used as a standard deviation value for the injection uncertainty distribution
    - `time_factor::Float64` : per hour increase ratio of the uncertainty's standard deviation 
"""
struct UncertaintyDistribution <: AbstractUncertaintyDist
    min_value::Float64
    max_value::Float64
    mu::Float64
    sigma::Float64
    time_factor::Float64
end

uncertainties[ech][nodal_injection_name][ts][scenario_name]
Uncertainties = Dict{Dates.DateTime, 
                        Dict{String,
                                Dict{Dates.DateTime,
                                        Dict{String, Float64}
                                        }
                                }
                        }


