
module SCOPF
    using Base: String
    using LinearAlgebra:length
    using SparseArrays, LinearAlgebra 
    using ..AmplTxt
    
    mutable struct Bus
        name::String
        id::Int
    end

    mutable struct Branch
        from::Int
        to::Int
        r::Float64
        x::Float64
    end
    function get_b(branch::Branch)
        return branch.x / sqrt(branch.r * branch.r + branch.x * branch.x)
    end
    mutable struct Network
        bus_to_i::Dict{Int,Int}
        branch_to_i::Dict{Int,Int}

        branches::Dict{Int,Branch}
    end
    function Network()
        return Network(Dict{Int,Int}(), Dict{Int,Int}(), Dict{Int,Branch}())
    end

    function Network(amplTxt)
        network = Network();
        add_bus!(network, amplTxt);
        add_branches!(network, amplTxt);
        add_generator!(network, amplTxt);
        return network
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
            num  = parse(Int, branch[2]);
            num_or = parse(Int, branch[3]);
            num_ex = parse(Int, branch[4]);
            
            if num_or != -1  && num_ex != -1
                id = get_or_add(num, network.branch_to_i);
                ior = get_or_add(num_or, network.bus_to_i);
                iex = get_or_add(num_ex, network.bus_to_i);
                r = parse(Float64, branch[8]);
                x = parse(Float64, branch[9]);
                push!(network.branches, id => Branch(ior, iex, r, x));
            end
        end
    end
    function add_bus!(network::Network, amplTxt)
        buses = amplTxt["buses"];
        for bus in buses.data
            num = parse(Int, bus[2]);
            numCC = parse(Int, bus[4]);
            if numCC == 0
                id = get_or_add(num, network.bus_to_i);

            end
        end
    end
    function add_generator!(network::Network, amplTxt)
        generators = amplTxt["generators"];
        for genData in generators.data
            gen = parse(Int, genData[2]);
            bus = parse(Int, genData[3]);
            conbus = parse(Int, genData[4]);
            minP = parse(Float64, genData[6]);
            maxP = parse(Float64, genData[7]);
        end
    end
    function get_B(network::Network, DIAG_EPS::Float64)
        B_dict = Dict{Tuple{Int,Int},Float64}();
        for kvp in collect(network.branches)
            b = get_b(kvp[2]);

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

    function get_PTDF(network::Network, binv::Matrix, ref_bus::Int)    
        n = length(network.bus_to_i);
        m = length(network.branches);
        println("n ", n)
        println("m ", m)
        PTDF = zeros(Float64, m, n);
        for kvp in collect(network.branches)
            b = get_b(kvp[2]);

            branchid = kvp[1];
            ior = kvp[2].from;
            iex = kvp[2].to;
            
            for i in 1:n
                if ior != ref_bus
                    PTDF[branchid, i] += b * binv[ior, i];
                end
                if iex != ref_bus
                    PTDF[branchid, i] += b * binv[iex, i];
                end
            end
        end
        return PTDF
    end
    export get_b;
    export add_bus!;
    export add_branches!;
    export get_B;
    export get_B_inv;
    export get_PTDF;
end

