# Chemin du projet
root_path = dirname(@__DIR__)

# Import des packages et des scripts
using Dates
using Random
#include(joinpath(root_path, "src", "PSCOPF.jl"))
include(joinpath(root_path, "src", "PTDF.jl"))

# Paramètres à fixer
input_path = joinpath(root_path, "data", "ptdf_test_light_5n")
output_path = joinpath(input_path, "output")
output_ptdf_file = joinpath(output_path, "pscopf_ptdf.txt")
slack_bus = 1
distributed_slack_bus = false

# Calcul de la matrice PTDF
network = PTDF.read_network(input_path)
ptdf = PTDF.compute_ptdf(network, slack_bus)
if distributed_slack_bus
    ptdf = PTDF.distribute_slack(ptdf);
end
PTDF.write_PTDF(output_ptdf_file, network, ptdf, distributed_slack_bus, slack_bus)