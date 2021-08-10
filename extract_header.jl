
cd("D:\\AppliRTE\\repo\\scopf-quanti")

include("split_with_spaces.jl")


GENERIC_HEADER = "ampl_network_"
GENERIC_EXTENSION = ".txt"

BASE_FILENAME_LIST = [
    "branches",
    "batteries",
    "buses",
    "generators",
    "hvdc",
    "lcc_converter_stations",
    "limits",
    "loads",
    "ptc",
    "rtc",
    "shunts",
    "static_var_compensators",
    "substations",
    "tct",
    "vsc_converter_stations"
];

headers =  Dict{String, Vector{String}}()
for name in BASE_FILENAME_LIST
    file_path = abspath(".", GENERIC_HEADER * name * GENERIC_EXTENSION)
    println("reading ", name, " in ", file_path)
    header = []
    open(file_path) do file
        i_line=0
        for ln in eachline(file)
            i_line+=1
            if i_line==2
                header = split_with_space(ln[2:end])
                println(header)
                break
            end
        end
    end
    push!(headers, name=>header)
end


for kvp in collect(headers)
    println(kvp, ", ")
end