using Dates

"""
    create_TS

Generates the target time points of the study.
These are the timepoints for which PSCOPF will decide on production levels.
For now, we have 4 taget timepoints starting at a reference timepoint `ts1` and separated by 15 minutes 

# Arguments
    - `ts1::Dates.DateTime` : the starting time of the target period of time for the study
"""
function create_target_timepoints(ts1::Dates.DateTime)
    return ts1 .+ [Dates.Minute(0), Dates.Minute(15), Dates.Minute(30), Dates.Minute(45)]
end
