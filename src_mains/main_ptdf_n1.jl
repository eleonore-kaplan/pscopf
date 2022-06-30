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
eps_diag = 1e-3

#########################
# EXECUTION
#########################
function main(input_path, ref_bus_num, distributed, eps_diag)
    network = PTDF.read_network(input_path)
    out_path = input_path
    PTDF.compute_and_write_n_non_bridges(network, ref_bus_num, distributed, eps_diag, input_path, out_path)
end

main(input_path, ref_bus_num, distributed, eps_diag)


# input_path = joinpath(@__DIR__, "..", "data_matpower", "case118")
# main(input_path, ref_bus_num, distributed, eps_diag)
