
# # read the itools ampl-txt files
# # read uncertainties
# # read production units data
# # compute PTDF: export text (scenario, ts, ech, state, bus, branch) --> PTDF value
# launcher = Workflow.Launcher(dir_path);
# dt = Dates.DateTime("2015-01-01-11:00",df)
# ech = Dates.DateTime("2015-01-01-11:00",df)

# Workflow.add_uncertainties(launcher, "name", "bus_name", ech, dt, 10)

# println(launcher.uncertainties)
# dt
# ech
# dt-ech


root_path = raw"D:\AppliRTE\repo\scopf-quanti"
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "ProductionUnits.jl"));
include(joinpath(root_path, "Workflow.jl"));

using Dates;
using Printf;
using Distributions;

test_name = "5buses_wind"
dir_path = joinpath(root_path, test_name);

pmax_uncertain = Dict{String, Float64}()

TYPE_ID=1
FAKE_ID=2
DMO_ID=3
VAR_ID=4
FIX_ID=5

flexibility = Dict([
    "coal"=>["coal", 600, 360, 50, 180000],
    "nuclear"=>["nuclear", 1000, 1440, 10, 1000000],
    "gas_conventional"=>["gas", 200, 300, 40, 40000],
    "gas_ccg"=>["gas", 500, 180, 40, 40000],
    "gas_ct"=>["gas", 200, 30, 120, 12000],
    "onshore"=>["wind", 0, 5, 50, 0],
    "pv"=>["solar", 0, 5, 50, 0] 
]);
id_fuel = Dict{String, String}();
open(joinpath(dir_path, "id_fuel.txt")) do file    
    for ln in eachline(file)
        # don't read commentted line 
        if ln[1] != '#'
            buffer = AmplTxt.split_with_space(ln);
            id_fuel[buffer[1]] = buffer[2];
        end
    end
end
id_fuel
###
# Uncertainties
###

N_SCENARIO = 1
df = Dates.DateFormat("Y-m-d-H:M")
h = Dates.DateTime("2015-01-01-11:00", df)
h_1 = Dates.DateTime("2015-01-01-10:00", df)
h_2 = Dates.DateTime("2015-01-01-09:00", df)
N_TIME_STEP=4
TIME_STEP =  [Minute(0), Minute(15), Minute(30), Minute(45)]
TIME_STEP =  [Minute(0)]
HORIZON = [h_2, h_1, h]

file_path = joinpath(dir_path, "capa_wind.txt");

_TYPE = 1;
_ID = 2;
_P = 3;
_PMAX = 4;
_μ = 6;
_σ = 5;

amplTxt = AmplTxt.read(test_name);

buses = amplTxt["buses"];
num_to_name= Dict{Int64, String}()
bus_load = Dict{Int64, Float64}()
for bus in buses.data
    num = parse(Int, bus[2]);
    name = bus[11];
    num_to_name[num] = name;
    bus_load[num]  = 0;
end

uncertainties = Vector{String}[]
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
SCENARIO = [@sprintf("S%d", x) for x in 1:N_SCENARIO]

loads = amplTxt["loads"];
for load in loads.data
    num = parse(Int, load[2]);
    bus = parse(Int, load[3]);
    p = parse(Float64, load[11]);
    bus_load[bus] = get(bus_load, bus, 0) + p
end
println(bus_load)

output_file_path = joinpath(dir_path, "pscopf_uncertainties.txt");
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
###
# Certainties
###
output_file_path = joinpath(dir_path, "pscopf_units.txt");
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


output_file_path = joinpath(dir_path, "pscopf_gen_type_bus.txt");
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
