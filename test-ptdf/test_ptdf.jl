using JuMP

using DataStructures
using Parameters
using Printf
using SparseArrays, LinearAlgebra

import Xpress

root_path = dirname(@__DIR__)
push!(LOAD_PATH, root_path);
cd(root_path)
include(joinpath(root_path, "src", "PTDF.jl"));


## programme d'optimisation pour calculer theta
function compute_theta(B,P)
    nb_buses = length(P);
    model = Model(Xpress.Optimizer);
    set_optimizer_attribute(model, "OUTPUTLOG", 0);

    @variable(model, theta[1:nb_buses]);
    @objective(model,Min,0);

    for i in range(1,nb_buses)
        @constraint(model,sum(B[i,j] * theta[j] for j in range(1,nb_buses)) == P[i]);
    end

    # print(model);

    optimize!(model);

    return [value(theta[i]) for i in range(1,nb_buses)];
end;



function compute_ptdf_by_optim(network::PTDF.Network,ref_bus_num::Int, EPS_DIAG::Float64)
    nb_buses = length(network.buses);
    nb_branches = length(network.branches);

    # calcul de B
    B=PTDF.get_B(network,EPS_DIAG,false);

    # calcul de la colonne de la PTDF pour chaque noeud
    PTDF_matrix = zeros(nb_branches,nb_buses);
    # println(network.buses)
    for bus in network.buses
        bus_num = bus[1]
        # println("$bus, id is $bus_num")
        #définition de la distribution des injections
        P = zeros(nb_buses);
        if bus_num != ref_bus_num
            P[bus_num]=1;
            P[ref_bus_num]+=-1;
        end

        #calcul de theta tel que B*theta = P
        theta = compute_theta(B,P);

        #calcul de la PTDF
        for branch in collect(network.branches)
            branch_num = branch[1];
            x_inv = PTDF.get_b(branch[2]);

            ior = branch[2].from;
            iex = branch[2].to;
            
            PTDF_matrix[branch_num,bus_num] = x_inv*(theta[ior]-theta[iex]);
        end
    end
    return PTDF_matrix;
end;

function compare_ptdfs(network::PTDF.Network,ref_bus_num::Int, EPS_DIAG::Float64)

    ptdf_optim = compute_ptdf_by_optim(network,ref_bus_num, EPS_DIAG);
    ptdf_with_inv = PTDF.compute_ptdf(network,ref_bus_num, EPS_DIAG);

    return ptdf_optim-ptdf_with_inv;
end;


##### Example
EPS_DIAG = 0e-6;
ref_bus_num = 1;
data_path_sparse = joinpath(@__DIR__, "..", "data_matpower", "case1354pegase");
data_path = data_path_sparse;

network = PTDF.read_network(data_path);

# ptdf_optim = compute_ptdf_by_optim(network,ref_bus_num);
ptdf_difference = norm(compare_ptdfs(network, ref_bus_num, EPS_DIAG));
println("error_max = $ptdf_difference");