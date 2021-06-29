
import CSV

cd("D:\\AppliRTE\\PROJET\\eod_rso");


@time df = CSV.File("matrice_sensibilites.csv");

println(propertynames(df))
# for row in df
#     println(row)
#     break
# end