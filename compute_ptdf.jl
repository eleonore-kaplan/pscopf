using SparseArrays: Vector
using Base: read_dependency_src, Int64
using LinearAlgebra:Matrix
using SparseArrays, LinearAlgebra 
using CSV, Tables
using Profile
import CSV

function get_or_add(i::Int64, d::Dict{Int64,Int64})
    if ! haskey(d, i)
        next_id = length(d) + 1;
        d[i] = next_id;
    end
    return d[i];
end


###
# rien de plus simple qu'une liste (branch, nor, nex, r, x)
###
mutable struct BasicNetwork
    bus_to_i::Dict{Int64,Int64}
    branch_to_i::Dict{Int64,Int64}
    B_dict::Dict{Tuple{Int64,Int64},Float64}
end

function BasicNetwork()
    bus_to_i = Dict{Int64,Int64}()
    branch_to_i = Dict{Int64,Int64}()
    B_dict = Dict{Tuple{Int64,Int64},Float64}()


    return BasicNetwork(bus_to_i, branch_to_i, B_dict)

end

function read_df(network::BasicNetwork, df, DIAG_EPS::Float64)
    for row in df
        # println("row is $row")
        bid = row.num;
        nor = row.bus1;
        nex = row.bus2;
        r = row.r;
        x = row.x;
        b = +x / (r * r + x * x);
        # println("bid is $bid, nor is $nor, nex is $nex, b is $b\n")
        branchid = get_or_add(bid, network.branch_to_i);
        ior = get_or_add(nor, network.bus_to_i);
        iex = get_or_add(nex, network.bus_to_i);
    
        # diagonal part
        network.B_dict[ior, ior] = get(network.B_dict, (ior, ior), DIAG_EPS) + b;
        network.B_dict[iex, iex] = get(network.B_dict, (iex, iex), DIAG_EPS) + b;
        network.B_dict[ior, iex] = get(network.B_dict, (ior, iex), 0) - b;
        network.B_dict[iex, ior] = get(network.B_dict, (iex, ior), 0) - b;
    end
end

function get_B(network::BasicNetwork)    
    Brow = Int64[];
    Bcol = Int64[];
    Bval = Float64[];
    for kvp in collect(network.B_dict)
        push!(Brow, kvp[1][1]);
        push!(Bcol, kvp[1][2]);
        push!(Bval, kvp[2]);
    end
    n = length(network.bus_to_i);
    B = sparse(Brow, Bcol, Bval, n, n);
    Bdense = Matrix(B);
    return Bdense
end

function get_n(network::BasicNetwork)
    return length(network.bus_to_i)
end
function get_m(network::BasicNetwork)
    return length(network.branch_to_i)
end

function get_B_inv(Bdense::Matrix, ref_bus::Int64)
    n = size(Bdense)[1]
    Bdense2 = Bdense
    Bdense2[ref_bus, 1:n] .= 0
    Bdense2[1:n, ref_bus] .= 0
    Bdense2[ref_bus, ref_bus] = 1
    binv = inv(Bdense2);
    # binv = copy(Bdense2)
    # ipiv =zeros(Int64, n)
    # LinearAlgebra.LAPACK.getri!(binv, ipiv)
    binv[ref_bus,ref_bus] = 0;
    return binv
end

function get_branch_name(df, network::BasicNetwork)
    n = get_n(network);
    m = get_m(network);
    branch_names = ["" for i in  1:m]
    
    for row in df
        nor = row.bus1;
        nex = row.bus2;
        branchid = get_or_add(row.num, network.branch_to_i);
        branch_names[branchid] =  string(nor, "_", nex);
    end
    return branch_names
end

function get_PTDF(df, network::BasicNetwork, binv::Matrix)    
    n = get_n(network);
    m = get_m(network);
    PTDF = zeros(Float64, m, n);

    # K = zeros(Float64, m, n);
    # Bd = zeros(Float64, m, m);
    for row in df
        bid = row.num;
        nor = row.bus1;
        nex = row.bus2;
        r = row.r;
        x = row.x;
        b = +x / (r * r + x * x);
        # println("bid is $bid, nor is $nor, nex is $nex, b is $b\n")
        branchid = get_or_add(bid, network.branch_to_i);
        ior = get_or_add(nor, network.bus_to_i);
        iex = get_or_add(nex, network.bus_to_i);
        # K[branchid, ior] += +1;
        # K[branchid, iex] += -1;
        # Bd[branchid, branchid]+=b;
        if ior != ref_bus
            PTDF[branchid, :] += b * binv[ior, :];
        end
        if iex != ref_bus
            PTDF[branchid, :] -= b * binv[iex, :];
        end
    end
    # PTDF = Bd*K*bInv
    return PTDF
end

function get_colnames(network::BasicNetwork)
    colnames = ["" for i in 1:n];
    for kvp in collect(network.bus_to_i)
        colnames[kvp[2]] = string(kvp[1]);
    end
    return colnames
end

cd("D:\\AppliRTE\\PROJET\\eod_rso");
DIAG_EPS = 1e-8
# @time df = CSV.File("4nodes.txt");
# @timedf = CSV.File("toto.txt");
@time df = CSV.File("branche_france.txt");
network = BasicNetwork()

read_df(network, df, DIAG_EPS)

# n = get_n(network);
# m = get_m(network);

# println("Number of buses :    ", n);
# println("Number of branches : ", m);

println("get_B")
@time Bdense = get_B(network)
 
ref_bus = 1
println("get_B_inv")
@time bInv = get_B_inv(Bdense, ref_bus)
println("get_PTDF")
@time PTDF = get_PTDF(df, network, bInv)
println("get_branch_name")
@time branch_names = get_branch_name(df, network)
println("CSV.write()")
@time CSV.write("PTDF.csv",  Tables.table(PTDF), writeheader=true, delim=';', header=get_colnames(network));

# for i in 1:m
#     println(branch_names[i])
# end