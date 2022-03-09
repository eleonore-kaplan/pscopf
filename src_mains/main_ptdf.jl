"""
    main_ptdf
A main file to generate a PTDF file

Parameters:
    input_path : path to input data directory describing a grid
                (not the pscopf_ files but branches.txt and buses.txt)
"""

using Dates

root_path = dirname(@__DIR__)
push!(LOAD_PATH, root_path);
cd(root_path)
include(joinpath(root_path, "src", "PTDF.jl"));




#########################
# INPUT & PARAMS
#########################

input_path = ( length(ARGS) > 0 ? ARGS[1] :
                    joinpath(@__DIR__, "..", "data", "ptdf") )


#########################
# EXECUTION
#########################
ref_bus_num = 1
PTDF.compute_ptdf(input_path, ref_bus_num)
