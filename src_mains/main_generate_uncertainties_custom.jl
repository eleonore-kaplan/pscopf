"""
    main_generate_uncertainties_custom
A main file allowing to generate uncertainties for a pscopf instance.
This provides an example to customize the uncertainties generation method
 by overloading the function `PSCOPF.generate_values`.

Parameters:
data_path : the path to network files (pscopf_limits, pscopf_units, pscopf_ptdf) and pscopf_init
out_path : path where pscopf_uncertainties will be written
copy_data_files : If true, input files will be rewritten to out_path
nb_scenarios : Number of uncertain scenarios generated
TS : interest timepoints for which an uncertain value is generated
uncertainties_distribution : The distribution of the injections uncertainties (c.f. uncertainties_distribution.txt)


To define a custom function for generating uncertain values, One can overload the function :
PSCOPF.generate_values(uncertainty_distribution,
                        ech::Dates.DateTime, ts::Dates.DateTime,
                        nb_scenarios::Int64)
"""

using Dates
using Distributions
using DataStructures

root_path = dirname(@__DIR__)
push!(LOAD_PATH, root_path);
cd(root_path)
include(joinpath(root_path, "src", "PSCOPF.jl"));




#########################
# INPUT & PARAMS
#########################

# data_path is the path used to read the network and generators initial state:
# pscopf_units : the description of the units
# pscopf_limits : the flow capacity of each branch
# pscopf_ptdf : the ptdf coefficients per (branch, bus_id)
# pscopf_init : the description of the initial state of units (just before the first interest timepoit T)
data_path = joinpath(@__DIR__, "..", "data", "2buses_small_usecase")

# out_path is the path where uncertainties file will be written:
# pscopf_uncertainties : the randomly generated nodal injections
out_path = joinpath(data_path, "custom_uncertainties")

# If true network and generator initial state files will be written to the out_path
copy_data_files = true

# Number of scenarios to be generated
nb_scenarios = 5

# interest time points (ie T)
ts1 = Dates.DateTime("2015-01-01T11:00:00")
TS = PSCOPF.create_target_timepoints(ts1) #T: 11h, 11h15, 11h30, 11h45

# uncertainties_distribution :
#distribution parameters used to generate injections uncertainties
uncertainties_distribution = SortedDict("wind_1" => [ 0, 10],
                                        "wind_2" => [10, 20],
                                        "bus_1" =>  [20, 50],
                                        "bus_2" =>  [50, 70])

function PSCOPF.generate_values(uncertainty_distribution,
                        ech::Dates.DateTime, ts::Dates.DateTime,
                        nb_scenarios::Int64)
    return rand(Uniform(uncertainty_distribution[1], uncertainty_distribution[2]), nb_scenarios)
end


#########################
# EXECUTION
#########################
function generate_uncerainties(output_path, input_path,
                                uncertainties_distribution, nb_scenarios,
                                TS::Vector{DateTime}, #T
                                ECH::Vector{DateTime}=Vector{DateTime}(); #ECH
                                write_data::Bool=true
                                )
    # load network
    println("load network")
    network = PSCOPF.Data.pscopfdata2network(input_path)

    #define ECH (ie t)
    if isempty(ECH)
        ECHs = []
        for mode in [PSCOPF.PSCOPF_MODE_1, PSCOPF.PSCOPF_MODE_2, PSCOPF.PSCOPF_MODE_3]
            push!(ECHs, PSCOPF.generate_ech(network, TS, mode) )
        end
        horizon_timepoints = sort(unique(Iterators.flatten(ECHs)))
    else
        horizon_timepoints = ECH
    end
    println("Uncertainties will be generated for horizon timepoints (ie. t) : ", horizon_timepoints)

    # generate uncertainties
    uncertainties = PSCOPF.generate_uncertainties(network, TS, horizon_timepoints,
                                                uncertainties_distribution, nb_scenarios)
    println("Uncertainties generated!")

    # write files
    PSCOPF.PSCOPFio.write(output_path, uncertainties)
    if write_data
        PSCOPF.PSCOPFio.write(output_path, network)
        generators_init_state = PSCOPF.PSCOPFio.read_initial_state(input_path)
        PSCOPF.PSCOPFio.write(output_path, generators_init_state)
    end
    println("Uncertainties written to ", output_path)
end


generate_uncerainties(out_path, data_path,
                        uncertainties_distribution, nb_scenarios,
                        TS,
                        write_data=copy_data_files)
