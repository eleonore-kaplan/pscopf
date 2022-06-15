"""
    main_ptdf
A main file to generate a PTDF file

Parameters:
    input_path : path to input data directory describing a grid
                (not the pscopf_ files but branches.txt and buses.txt)
"""

using Dates
using Printf

root_path = dirname(@__DIR__)
push!(LOAD_PATH, root_path);
cd(root_path)
include(joinpath(root_path, "src", "PTDF.jl"));




#########################
# INPUT & PARAMS
#########################

input_path = ( length(ARGS) > 0 ? ARGS[1] :
                    joinpath(@__DIR__, "..", "data", "ptdf", "3buses_3branches") )
ref_bus_num = 1
distributed = true


#########################
# EXECUTION
#########################
network = PTDF.read_network(input_path)
PTDF.compute_and_write_all(network, ref_bus_num, distributed, input_path)

