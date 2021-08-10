# D:\AppliRTE\repo\naza-mpc\powsybl\bin\itools convert-network --input-file 24Nodes.xiidm --output-file ampl --output-format AMPL
module AmplTxt
    const GENERIC_HEADER = "ampl_network_";
    const GENERIC_EXTENSION = ".txt";

    const FILENAME_COLNAME = Dict(
        "rtc" => ["variant", "num", "tap", "table", "onLoad", "fault", "curative", "id"],
        "hvdc" => ["variant", "num", "type", "converterStation1", "converterStation2", "r (ohm)", "nomV (KV)", "convertersMode", "targetP (MW)", "maxP (MW)", "fault", "curative", "id", "description"],
        "limits" => ["variant", "num", "branch", "side", "limit (A)", "accept. duration (s)", "fault", "curative"],
        "generators" => ["variant", "num", "bus", "con. bus", "substation", "minP (MW)", "maxP (MW)", "minQmaxP (MVar)", "minQ0 (MVar)", "minQminP (MVar)", "maxQmaxP
        (MVar)", "maxQ0 (MVar)", "maxQminP (MVar)", "v regul.", "targetV (pu)", "targetP (MW)", "targetQ (MVar)", "fault", "curative", "id", "description", "P (MW)",
        "Q (MVar)"],
        "batteries" => ["variant", "num", "bus", "con. bus", "substation", "p0 (MW)", "q0 (MW)", "minP (MW)", "maxP (MW)", "minQmaxP (MVar)", "minQ0 (MVar)", "minQminP (MVar)", "maxQmaxP (MVar)", "maxQ0 (MVar)", "maxQminP (MVar)", "fault", "curative", "id", "description", "P (MW)", "Q (MVar)"],
        "buses" => ["variant", "num", "substation", "cc", "v (pu)", "theta (rad)", "p (MW)", "q (MVar)", "fault", "curative", "id"],
        "tct" => ["variant", "num", "tap", "var ratio", "x (pu)", "angle (rad)", "fault", "curative"],
        "loads" => ["variant", "num", "bus", "substation", "p0 (MW)", "q0 (MVar)", "fault", "curative", "id", "description", "p (MW)", "q (MVar)"],
        "branches" => ["variant", "num", "bus1", "bus2", "3wt num", "sub.1", "sub.2", "r (pu)", "x (pu)", "g1 (pu)", "g2 (pu)", "b1 (pu)", "b2 (pu)", "cst ratio (pu)", "ratio tc", "phase tc", "p1 (MW)", "p2 (MW)", "q1 (MVar)", "q2 (MVar)", "patl1 (A)", "patl2 (A)", "merged", "fault", "curative", "id", "description"],
        "shunts" => ["variant", "num", "bus", "con. bus", "substation", "minB (pu)", "maxB (pu)", "inter. points", "b (pu)", "fault", "curative", "id", "description", "P (MW)", "Q (MVar)", "sections count"],
        "substations" => ["variant", "num", "unused1", "unused2", "nomV (KV)", "minV (pu)", "maxV (pu)", "fault", "curative", "country", "id", "description"],
        "static_var_compensators" => ["variant", "num", "bus", "con. bus", "substation", "minB (pu)", "maxB (pu)", "v regul.", "targetV (pu)", "targetQ (MVar)", "fault", "curative", "id", "description", "P (MW)", "Q (MVar)"],
        "ptc" => ["variant", "num", "tap", "table", "fault", "curative", "id"],
        "vsc_converter_stations" => ["variant", "num", "bus", "con. bus", "substation", "minP (MW)", "maxP (MW)", "minQmaxP (MVar)", "minQ0 (MVar)", "minQminP (MVar)", "maxQmaxP (MVar)", "maxQ0 (MVar)", "maxQminP (MVar)", "v regul.", "targetV (pu)", "targetQ (MVar)", "lossFactor (%PDC)", "fault", "curative", "id", "description", "P (MW)", "Q (MVar)"],
        "lcc_converter_stations" => ["variant", "num", "bus", "con. bus", "substation", "lossFactor (%PDC)", "powerFactor", "fault", "curative", "id", "description",
        "P (MW)", "Q (MVar)"]
    )
    export AmplTxtDataRow;
    mutable struct AmplTxtDataRow
        colNameIdx::Dict{String,Int64}

        data::Vector{Vector{String}}
    end

    function readNetworkData(name::String, root::String)
        file_path = abspath(root, GENERIC_HEADER * name * GENERIC_EXTENSION)
        println("reading ", name, " in ", file_path)
        colNameIdx =  Dict{String,Int64}()
        idx = 1
        colNames = FILENAME_COLNAME[name]
        for col in colNames
            push!(colNameIdx, col => idx)
            idx += 1
        end

        data = Vector{String}[]
        open(file_path) do file
            for ln in eachline(file)
                # don't read commentted line 
                if ln[1] != '#'
                    push!(data, split_with_space(ln))
                end
            end
            # println(data)
        end
        return AmplTxtDataRow(colNameIdx, data)
    end

    function readNetworkData(name::String)
        return readNetworkData(name, ".")
    end
    
    function split_with_space(str::String)
        result = String[]
        if length(str) > 0
            start_with_quote = startswith(str, "\"")
            buffer_quote = split(str, keepempty=false, "\"")
            i = 1
            while i <= length(buffer_quote) 
                if i > 1 || !start_with_quote
                    str2 = buffer_quote[i]
                    buffer_space = split(str2, keepempty=false)
                    for str3 in buffer_space
                        push!(result, str3)
                    end
                    i += 1
                end
                if i <= length(buffer_quote)
                    push!(result, buffer_quote[i])
                    i += 1
                end
            end
        end    
        return result
    end
    function read()
        return read(".")
    end
    function read(root::String)
        amplTxt = Dict{String,AmplTxtDataRow}()
        for kvp in collect(FILENAME_COLNAME)
            name = kvp[1]
            data = readNetworkData(name, root)
            push!(amplTxt, name => data)
        end
        return amplTxt
    end
end
