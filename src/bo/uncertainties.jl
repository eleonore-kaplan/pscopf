#TODO
using Dates
using DataStructures

"""
    UncertaintyDistribution

describes the uncertainty distribution of an injection (load or renewable)
We consider `ts` as the target timepoint at which the realisation will have place,
and `ech` is the observation point.
The farthest we are from ts, the greater is the uncertainty: we assume an increase  by a ratio of `time_factor` for each hour.
i.e.: factor_l = ( max{ 0, ( ts - ech )/1h } * time_factor ) ^ cone_effect
adjusted_sigma = factor_l * sigma
random_injection = mu * (1 + rand(Normal(0, adjusted_sigma)) )

# Arguments
    - `min_value::Float64` : minimum value that can be assigned to the injection
    - `max_value::Float64` : maxiimum value that can be assigned to the injection
    - `mu::Float64` : average injection value
    - `sigma::Float64` : base sigma value to be used as a standard deviation value for the injection uncertainty distribution
    - `time_factor::Float64` : per hour increase ratio of the uncertainty's standard deviation
    - `cone_effect::Float64` : variability of the uncertainty's standard deviation wrt time axis (timefactor > 0 => the cone uncertainty hypothesis)
"""
struct UncertaintyDistribution
    id::String
    min_value::Float64
    max_value::Float64
    mu::Float64
    sigma::Float64
    time_factor::Float64
    cone_effect::Float64
end

# uncertainties[ech][nodal_injection_name][ts][scenario_name]
Uncertainties = SortedDict{Dates.DateTime,
                        SortedDict{String,
                                SortedDict{Dates.DateTime,
                                        SortedDict{String, Float64}
                                        }
                                }
                        }

function add_uncertainty!(uncertainties::Uncertainties, ech::Dates.DateTime, nodal_injection_name::String, ts::Dates.DateTime, scenario_name::String, val::Float64)
    get!(uncertainties, ech, SortedDict{String, SortedDict{Dates.DateTime, SortedDict{String, Float64}}}())
    get!(uncertainties[ech], nodal_injection_name, SortedDict{Dates.DateTime, SortedDict{String, Float64}}())
    get!(uncertainties[ech][nodal_injection_name], ts, SortedDict{String, Float64}())

    uncertainties[ech][nodal_injection_name][ts][scenario_name] = val
    return uncertainties
end
