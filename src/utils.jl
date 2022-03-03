
"""
    redirect_to_file(f::Function, file_p::String, mode_p="w")

Execute function `f` while redirecting C and Julia level stdout to the file file_p.
Note that `file_p` is open in write mode by default.

# Arguments
- `f::Function` : the function to execute
- `file_p::String` : name of the file to print to
- `mode_p` : open mode of the file (defaults to "w")
"""
function redirect_to_file(f::Function, file_p::String, mode_p="w")
    open(file_p, mode_p) do file_l
        redirect_to_file(f, file_l)
    end
end
function redirect_to_file(f::Function, io::IO)
    Base.Libc.flush_cstdio()
    redirect_stdout(io) do
        f()
        Base.Libc.flush_cstdio()
    end
end

function pretty_print(io::IO, d::AbstractDict; spacing=1, sort_p::Bool=false)
    d_l = d
    if sort_p
        d_l = sort(d)
    end
    for (k,v) in d_l
        if typeof(v) <: AbstractDict
            str_k = "$(repr(k)) => "
            print(io, join(fill(" ", spacing)), str_k, "\n")
            pretty_print(io, v, spacing=spacing+1+length(str_k), sort_p=sort_p)
        else
            print(io, join(fill(" ", spacing)), k, " => ", v, "\n")
        end
    end
    nothing
end

function rm_non_prefixed(dir::String, prefix::String)
    non_prefixed = filter(!startswith(prefix), readdir(dir))
    paths = joinpath.(dir, non_prefixed)
    files_to_rm = filter(isfile, paths)
    foreach(rm, files_to_rm)
end
