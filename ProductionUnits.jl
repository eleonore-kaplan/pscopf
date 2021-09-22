module ProductionUnits
    using Base: String
    using Printf
    using Base:Tuple

    # using ..SCOPF
    using ..AmplTxt
    export write_uncertainties;
    export read_uncertainties;
    export extract_uncertainties;

    function read_uncertainties(file_path::String)
        result = Dict{Tuple{String,String,Int64,Int64},Float64}()
        open(file_path) do file
            for ln in eachline(file)
                if ln[1] != '#'
                    buffer = split_with_space(ln)
                    scenario = buffer[1]
                    name = buffer[2]
                    ts = parse(Int64, buffer[3])
                    ech = parse(Int64, buffer[4])
                    value = parse(Float64, buffer[5])
                    push!(result, (scenario, name, ts, ech) => value)
                end
            end
        end        
        return result
    end

    function write_uncertainties(data::Dict{Tuple{String,String,Int64,Int64},Float64}, file_path::String)
    open(file_path, "w") do file
        for kvp in collect(data)
            write(file, @sprintf("%s %s %d %d %.6E\n", kvp[1][1], kvp[1][2], kvp[1][3], kvp[1][4], kvp[2]))
            end
        end        
    end

    function extract_uncertainties(amplTxt, name::String, id_name::Int64, id_value::Int64, SCENARIO, TS, ECH)
        println(SCENARIO)
        result = Dict{Tuple{String,String,Int64,Int64},Float64}()
        for kvp in amplTxt[name].data
            name = kvp[id_name]
            value=parse(Float64,kvp[id_value])
            for scenario in SCENARIO, ts in TS, ech in ECH
                push!(result, (scenario, name, ts, ech)=>value)
            end
        end
        return result
    end

    function extract_uncertainties(amplTxt, SCENARIO, TS, ECH)

        gen = extract_uncertainties(amplTxt, "generators", 20, 22, SCENARIO, TS, ECH)
        load = extract_uncertainties(amplTxt, "loads", 9, 11, SCENARIO, TS, ECH)
        merge!(gen, load)
        return gen
    end

    mutable struct Unit
        name::String
        type::String
        startup_cost::Float64
        activation_cost::Float64
        variable_cost::Float64
        reserve_hausse::Float64
        reserve_baisse::Float64

        imposable::Bool
    end

    mutable struct Load
        name::String
    end

    # # to be renamed
    # mutable struct Problem
    #     units::Dict{String, Unit}
    #     loads::Dict{String, Load}
    #     uncertainties::Dict{Tuple{String,String,Int64,Int64},Float64}
    #     network::SCOPF.Network
    # end

    # function get_uncertainty(problem::Problem, scenario::String, name::String, ts::Int64, ech::Int64)
    #     return problem.uncertainties[scenarion, name, ts, ech];
    # end
end