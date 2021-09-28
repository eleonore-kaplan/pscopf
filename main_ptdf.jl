root_path = raw"D:\AppliRTE\repo\scopf-quanti"
push!(LOAD_PATH, root_path);
cd(root_path);

include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "SCOPF.jl"));
include(joinpath(root_path, "ProductionUnits.jl"));
include(joinpath(root_path, "FakeData.jl"));


include(joinpath(root_path, "AmplTxt.jl"));
using Printf
# Compute ptdf and export them as node branch value file

test_name = "5buses"

amplTxt = AmplTxt.read(test_name);
test_path = joinpath(root_path, test_name)
network = SCOPF.Network(amplTxt);

ref_bus = 3;
B = SCOPF.get_B(network, 1e-6);
Binv = SCOPF.get_B_inv(B, ref_bus);
PTDF = SCOPF.get_PTDF(network, Binv, ref_bus);

n = length(network.bus_to_i);
m = length(network.branches);

PTDF_TRIMMER = 1e-6;

println(PTDF);
open( joinpath(test_path, "ptdf.txt"), "w") do file     
    ref_name =  @sprintf("\"%s\"", network.buses[ref_bus].name)
    write(file, @sprintf("%20s %20s\n", "REF_BUS", ref_name))
    for branch_id in 1:m
        for bus_id in 1:n
            branch_name =  @sprintf("\"%s\"", network.branches[branch_id].name)
            bus_name =  @sprintf("\"%s\"", network.buses[bus_id].name)
            if abs(PTDF[branch_id,bus_id])>PTDF_TRIMMER
                @printf("%10s %10s %6d %6d %15.6E\n", branch_name, bus_name, branch_id, bus_id, PTDF[branch_id,bus_id])
                write(file, @sprintf("%20s %20s %20.6E\n", branch_name, bus_name,PTDF[branch_id,bus_id]))
            end
        end
    end
end
# buses = amplTxt["buses"];
# for bus in buses.data
#     num = parse(Int, bus[2]);
#     numCC = parse(Int, bus[4]);
#     if numCC == 0
#         println(bus[11])
#     end
# end