root_path = raw"D:\AppliRTE\repo\scopf-quanti"
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "Workflow.jl"));

test_name = "5buses_wind"
dir_path = joinpath(root_path, test_name);

launcher = Workflow.Launcher(dir_path);
##############################################################
### optimisation modelling sets
##############################################################
ECH,TS, S, NAMES = Workflow.get_ech_ts_s_name(launcher);
BUSES =  Workflow.get_bus(launcher, NAMES);
units_by_kind = Workflow.get_units_by_kind(launcher);
units_by_bus =  Workflow.get_units_by_bus(launcher, BUSES);
netloads = Dict([(bus, ts, s) => launcher.uncertainties[bus, s, ts, ech] for bus in BUSES, ts in TS, s in S])
println("Number of scenario ", length(S));
println("Number of time step is ", length(TS));
println(ECH)
K_IMPOSABLE = Workflow.K_IMPOSABLE;
K_LIMITABLE = Workflow.K_LIMITABLE;

##############################################################
# to be in a function ...
##############################################################
using JuMP;
using Dates: DateTime;
using Printf;
model = Model();

# p_limitable[ts, s]  = min(p0[ts, s], pMax[ts])
p_limitable = Dict{Tuple{String, DateTime, String}, VariableRef}()
for kvp in units_by_kind[K_LIMITABLE], ts in TS, s in S
    name =  @sprintf("p_limitable[%s,%s,%s]", kvp[1], ts, s);
    p_limitable[kvp[1], ts, s] = @variable(model, base_name=name);
end

p_imposable = Dict{Tuple{String, DateTime, String}, VariableRef}()
for kvp in units_by_kind[K_IMPOSABLE], ts in TS, s in S
    name =  @sprintf("p_imposable[%s,%s,%s]", kvp[1], ts, s);
    p_imposable[kvp[1], ts, s] = @variable(model, base_name=name);
end

# println(units_by_kind)
# println(p_imposable)

eod_expr = Dict([(bus, ts, s)=>AffExpr(0) for bus in BUSES, ts in TS, s in S]);
ech=DateTime("2015-01-01T09:00:00")
for bus in BUSES, ts in TS, s in S
    for gen in units_by_bus[K_IMPOSABLE][bus]
        eod_expr[bus, ts, s] += p_imposable[gen, ts, s]
    end
    for gen in units_by_bus[K_LIMITABLE][bus]
        eod_expr[bus, ts, s] += p_limitable[gen, ts, s]
    end
end
# println(launcher.uncertainties)
for bus in BUSES, ts in TS, s in S
    @constraint(model, eod_expr[bus, ts, s] == netloads[bus, ts, s])
end
# println(units_by_bus)
# println(eod_expr)

println(model)