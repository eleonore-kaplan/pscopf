
module SCOPFutils

function pretty_print(d::Dict; spacing=1, sort_p::Bool=false)
    d_l = d
    if sort_p
        d_l = sort(d)
    end
    for (k,v) in d_l
        if typeof(v) <: Dict
            str_k = "$(repr(k)) => "
            println(join(fill(" ", spacing)), str_k)
            pretty_print(v, spacing=spacing+1+length(str_k), sort_p=sort_p)
        else
            println(join(fill(" ", spacing)), k, " => ", v)
        end
    end
    nothing
end

end #module SCOPFutils
