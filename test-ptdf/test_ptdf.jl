using JuMP

using DataStructures
using Parameters
using Printf
using SparseArrays, LinearAlgebra

import Cbc

include("../src/PTDF.jl")



## modification de get_B avec return de la sparse matrix
function get_B(network::PTDF.Network, DIAG_EPS::Float64, dense::Bool=true)
    B_dict = Dict{Tuple{Int,Int},Float64}();
    for kvp in collect(network.branches)
        b = PTDF.get_b(kvp[2]);

        ior = kvp[2].from;
        iex = kvp[2].to;


        # ior->iex
        # + dans ior
        # - dans iex

        # diagonal part
        # sur ior
        # +theta_ior
        # -theta_iex
        B_dict[ior, ior] = get(B_dict, (ior, ior), DIAG_EPS) + b;
        B_dict[ior, iex] = get(B_dict, (ior, iex), 0) - b;

        # sur iex
        # -theta_ior
        # +theta_iex
        B_dict[iex, ior] = get(B_dict, (iex, ior), 0) - b;
        B_dict[iex, iex] = get(B_dict, (iex, iex), DIAG_EPS) + b;


        # B_dict[ior, ior] = get(B_dict, (ior, ior), DIAG_EPS) + b;
        # B_dict[iex, iex] = get(B_dict, (iex, iex), DIAG_EPS) - b;

        # B_dict[ior, iex] = get(B_dict, (ior, iex), 0) + b;
        # B_dict[iex, ior] = get(B_dict, (iex, ior), 0) - b;
    end
    Brow = Int[];
    Bcol = Int[];
    Bval = Float64[];
    for kvp in collect(B_dict)
        push!(Brow, kvp[1][1]);
        push!(Bcol, kvp[1][2]);
        push!(Bval, kvp[2]);
    end
    n = length(network.bus_to_i);
    println("n = ", n)
    B = sparse(Brow, Bcol, Bval, n, n);
    if dense
        return B
    else
        Bdense = Matrix(B);
        return Bdense
    end
end;


## programme d'optimisation pour calculer theta
function compute_theta(B,P)
    nb_buses = length(P);
    model = Model(Cbc.Optimizer);

    @variable(model, theta[1:nb_buses]);
    @objective(model,Min,0);

    for i in range(1,nb_buses)
        @constraint(model,sum(B[i,j] * theta[j] for j in range(1,nb_buses)) == P[i]);
    end

    print(model)

    optimize!(model);

    return [value(theta[i]) for i in range(1,nb_buses)]
end;



function compute_ptdf_with_jump(network::PTDF.Network,ref_bus_num::Int)
    nb_buses = length(network.buses);
    nb_branches = length(network.branches);

    # calcul de B
    B=get_B(network,1e-6,false);

    # calcul de la colonne de la PTDF pour chaque noeud
    PTDF_matrix = zeros(nb_branches,nb_buses);
    for bus in collect(network.buses)
        bus_num = bus[1]

        #définition de la distribution des injections
        P = zeros(nb_buses);
        P[bus_num]=1;
        P[ref_bus_num]+=-1;

        #calcul de theta tel que B*theta = P
        theta = compute_theta(B,P);
        println(theta)
        println()

        #calcul de la PTDF
        for branch in collect(network.branches)
            branch_num = branch[1];
            x_inv = PTDF.get_b(branch[2]);

            ior = branch[2].from;
            iex = branch[2].to;
            
            PTDF_matrix[branch_num,bus_num] += x_inv*(theta[ior]-theta[iex]);
        end

        return PTDF_matrix
    end
end;

function compare_ptdfs(network::PTDF.Network,ref_bus_num::Int=1)
    ptdf_with_jump = compute_ptdf_with_jump(network,ref_bus_num)
    ptdf_with_inv = PTDF.compute_ptdf(network,ref_bus_num)

    return maximum(ptdf_with_jump-ptdf_with_inv)
end;


##### Example

data_path_small = joinpath(@__DIR__, "ptdf_small")
data_path_sparse = joinpath(@__DIR__, "ptdf_sparse")
data_path = data_path_sparse;

network = PTDF.read_network(data_path);
collect(network.buses)[3]


compare_ptdfs(network,1)

compute_ptdf_with_jump(network,1)
PTDF.compute_ptdf(network,1)