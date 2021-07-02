
module SCOPF
    using SparseArrays, LinearAlgebra 
    using ..AmplTxt
    mutable struct Bus
    end
    mutable struct Unit
    end
    mutable struct Load
    end
    mutable struct Branch
        from::Int
        to::Int
        r::Float64
        x::Float64
    end
    function get_b(branch::Branch)
        return branch.x / sqrt(branch.r*branch.r+branch.x*branch.x)
    end
    mutable struct Network
        # mapping
        bus_to_i::Dict{Int,Int}
        branch_to_i::Dict{Int,Int}

        branches::Dict{Int,Branch}
    end
    function Network()
        return Network(Dict{Int,Int}(), Dict{Int,Int}(), Dict{Int,Branch}())
    end
    function get_or_add(i::Int, d::Dict{Int,Int})
        if ! haskey(d, i)
            next_id = length(d) + 1;
            d[i] = next_id;
        end
        return d[i];
    end
    function add_branches!(network::Network, amplTxt)
        branches = amplTxt["branches"];
        for branch in branches.data
            # println(branch)
            num  = parse(Int, branch[2])
            num_or = parse(Int, branch[3])
            num_ex = parse(Int, branch[4])
            id = get_or_add(num, network.branch_to_i)
            if num_or != -1  && num_ex != -1
                ior = network.bus_to_i[num_or]
                iex = network.bus_to_i[num_ex]
                r = parse(Float64, branch[8])
                x = parse(Float64, branch[9])
                push!(network.branches, id=>Branch(ior, iex, r, x))
            end
        end
    end
    function add_bus!(network::Network, amplTxt)
        buses = amplTxt["buses"];
        for bus in buses.data
            num = parse(Int, bus[2])
            get_or_add(num, network.bus_to_i)
        end
    end
    function get_B(network::Network, DIAG_EPS::Float64)
        B_dict = Dict{Tuple{Int,Int},Float64}()
        for kvp in collect(network.branches)
            b = get_b(kvp[2]);

            branchid = kvp[1];
            ior = kvp[2].from;
            iex = kvp[2].to;
        
            # diagonal part
            B_dict[ior, ior] = get(B_dict, (ior, ior), DIAG_EPS) + b;
            B_dict[iex, iex] = get(B_dict, (iex, iex), DIAG_EPS) + b;
            B_dict[ior, iex] = get(B_dict, (ior, iex), 0) - b;
            B_dict[iex, ior] = get(B_dict, (iex, ior), 0) - b;
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
        Bdense = Matrix(B);
        return Bdense
    end
    
    
    function get_B_inv(Bdense::Matrix, ref_bus::Int64)
        println("ref_bus is ", ref_bus)
        n = size(Bdense)[1]
        Bdense2 = Bdense
        Bdense2[ref_bus, 1:n] .= 0
        Bdense2[1:n, ref_bus] .= 0
        Bdense2[ref_bus, ref_bus] = 1
        binv = inv(Bdense2);
        binv[ref_bus,ref_bus] = 0;
        return binv
    end

    export get_b;
    export add_bus!
    export add_branches!
end