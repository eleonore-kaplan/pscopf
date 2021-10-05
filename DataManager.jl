
TYPE_ID=1;
FAKE_ID=2;
DMO_ID=3;
VAR_ID=4;
FIX_ID=5;
_TYPE = 1;
_ID = 2;
_P = 3;
_PMAX = 4;
_μ = 6;
_σ = 5;

function read_id_fuel(dir_path::String)
    # id_fuel = read_id_fuel_txt(dir_path);
    id_fuel = read_id_fuel_csv(dir_path);
    return id_fuel; 
end
function read_id_fuel_txt(dir_path::String)
    id_fuel = Dict{String, String}();
    file_path = joinpath(dir_path, "id_fuel.txt")
    open(file_path) do file    
        for ln in eachline(file)
            # don't read commentted line 
            if ln[1] != '#'
                buffer = AmplTxt.split_with_space(ln);
                id_fuel[buffer[1]] = buffer[2];
            end
        end
    end
    return id_fuel; 
end
function read_id_fuel_csv(dir_path::String)
    id_fuel = Dict{String, String}();
    file_path = joinpath(dir_path, "generators.csv")
    open(file_path) do file  
        i = 0;  
        for ln in eachline(file)
            i+=1;
            if i>1
                buffer = split(ln, ";");
                id_fuel[buffer[1]] = buffer[2];
            end
        end
    end
    return id_fuel; 
end
function read_uncertainties(dir_path::String)    
    uncertainties = Vector{String}[];
    pmax_uncertain = Dict{String, Float64}();
    file_path = joinpath(dir_path, "capa_wind.txt");
    open(file_path) do file    
        for ln in eachline(file)
            # don't read commentted line 
            if ln[1] != '#'
                buffer = AmplTxt.split_with_space(ln);
                push!(uncertainties, buffer)
                pmax_uncertain[buffer[_ID]] = parse(Float64, buffer[_PMAX]);
            end
        end
    end
    return uncertainties, pmax_uncertain;
end

function read_bus_load(ampltxt)
    buses = amplTxt["buses"];
    num_to_name= Dict{Int64, String}()
    bus_load = Dict{Int64, Float64}()
    for bus in buses.data
        num = parse(Int, bus[2]);
        name = bus[11];
        num_to_name[num] = name;
        bus_load[num]  = 0;
    end
    loads = amplTxt["loads"];
    for load in loads.data
        num = parse(Int, load[2]);
        bus = parse(Int, load[3]);
        p = parse(Float64, load[11]);
        bus_load[bus] = get(bus_load, bus, 0) + p;
    end
    return num_to_name, bus_load;
    
end
function write_pscopf_uncertainties(output_file_path, uncertainties, SCENARIO, HORIZON, TIME_STEP)
    open(output_file_path, "w") do file     
        write(file, @sprintf("#%-9s%25s%25s%10s%10s\n", "id", "h_15m", "ech","scenario", "v"))
        for uncertainty in uncertainties
            for ech in HORIZON, ts in TIME_STEP
                id = uncertainty[_ID];
                p = parse(Float64, uncertainty[_P]);
                pMax = parse(Float64, uncertainty[_PMAX]);
                real_h = h+ts
                factor=1
                if ech == h
                    factor = 0.5
                elseif ech==h_2
                    factor = 2
                end

                μ = factor*parse(Float64, uncertainty[_μ]);
                σ = factor*parse(Float64, uncertainty[_σ]);            

                normal = rand(Normal(μ, σ), N_SCENARIO);
                i = 0;
                for scenario in SCENARIO
                    i += 1
                    v =  p + normal[i] * pMax
                    v = min(pMax, v)
                    v = max(0, v)
                    # println(@sprintf("%10s%10.3f%10.3f", id, p, v))
                    write(file, @sprintf("%-10s%25s%25s%10s%10.3f\n", id, real_h,ech, scenario,  v))
                end
            end
        end
        generators = amplTxt["generators"];
        for genData in generators.data
            gen = parse(Int, genData[2]);
            p = parse(Float64, genData[16]);
            name = genData[20];
            for ech in HORIZON, scenario in SCENARIO, ts in TIME_STEP   
                real_h = h+ts
                write(file, @sprintf("%-10s%25s%25s%10s%10.3f\n", name,real_h, ech, scenario,  p))
            end
        end
        
        for kvp in bus_load
            bus = kvp[1]
            name = num_to_name[bus]
            v = kvp[2]
            for ech in HORIZON, scenario in SCENARIO, ts in TIME_STEP   
                real_h = h+ts
                write(file,  @sprintf("%-10s%25s%25s%10s%10.3f\n",name,real_h, ech, scenario, v))
            end
        end

    end
end

function write_pscopf_units(output_file_path, amplTxt, id_fuel, flexibility)
    open(output_file_path, "w") do file     
        write(file, @sprintf("#%-9s %13s %13s %13s %13s %13s\n", "name", "p", "minP", "maxP", "start", "prop"))
        generators = amplTxt["generators"];
        for genData in generators.data
            gen = parse(Int, genData[2]);
            bus = parse(Int, genData[3]);
            conbus = parse(Int, genData[4]);
            minP = parse(Float64, genData[6]);
            maxP = parse(Float64, genData[7]);
            p = parse(Float64, genData[16]);
            name = genData[20];

            fuel = id_fuel[name]

            carac = flexibility[fuel]

            start_cost = carac[FIX_ID];
            prop_cost = carac[VAR_ID];
            write(file, @sprintf("%-10s %.8E %.8E %.8E %.8E %.8E\n", name, p, minP, maxP, start_cost, prop_cost))
        end
    end
    
end

function write_pscopf_gen_type_bus(output_file_path, amplTxt, id_fuel, num_to_name)        
    open(output_file_path, "w") do file     
        generators = amplTxt["generators"];
        for genData in generators.data
            gen = parse(Int, genData[2]);
            bus = parse(Int, genData[3]);
            conbus = parse(Int, genData[4]);        
            name = genData[20];

            fuel = id_fuel[name]
            if fuel in ["onshore", "pv"]
                kind  ="Limitable"
            else
                kind = "Imposable"
            end
            write(file, @sprintf("%s %s %s\n",name, kind,  num_to_name[conbus]))
        end
    end

end

function read_flexibility(dir_path)
    # flexibility =read_flexibility_hard(dir_path);
    flexibility =read_flexibility_csv(dir_path);
    return flexibility;
end

function read_flexibility_hard(dir_path)
    flexibility = Dict([
        "coal"=>["coal", 600, 360, 50, 180000],
        "nuclear"=>["nuclear", 1000, 1440, 10, 1000000],
        "gas_conventional"=>["gas", 200, 300, 40, 40000],
        "gas_ccg"=>["gas", 500, 180, 40, 40000],
        "gas_ct"=>["gas", 200, 30, 120, 12000],
        "onshore"=>["wind", 0, 5, 50, 0],
        "pv"=>["solar", 0, 5, 50, 0] 
    ]);
end
function read_flexibility_csv(dir_path)
    flexibility = Dict{String, Vector{Any}}();
    file_path = joinpath(dir_path, "flexibility.csv")
    open(file_path) do file  
        i = 0;  
        for ln in eachline(file)
            i+=1;
            if i>2
                buffer = split(ln, ";");
                name = buffer[1];
                type = buffer[2];
                p = parse(Float64,buffer[3]);
                dmo =parse(Float64,buffer[4]);
                variable =parse(Float64,buffer[5]);
                fixed  =parse(Float64,buffer[6]);
                push!(flexibility, type=>[name, p, dmo, variable, fixed]);
            end
        end
    end
    return flexibility; 
end
