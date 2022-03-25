import Logging
import LoggingExtras

"""
    Sets a two-logger TeeLogger as the global_logger:
    - the current logger
    - a logger to a file with debug minimum level

# Arguments
- `dir_p` : directory to which the log file will be created
"""
function init_logging(dir_p)
    """
    formats output to only print source_info for level > Warn
    """
    function logger_metafmt(level::Logging.LogLevel, _module, group, id, file, line)
        @nospecialize
        color = Logging.default_logcolor(level)
        prefix = string(level == Logging.Warn ? "Warning" : string(level), ':')
        suffix::String = ""
        level < Logging.Warn && return color, prefix, suffix
        _module !== nothing && (suffix *= "$(_module)")
        if file !== nothing
            _module !== nothing && (suffix *= " ")
            suffix *= Base.contractuser(file)::String
            if line !== nothing
                suffix *= ":$(isa(line, UnitRange) ? "$(first(line))-$(last(line))" : line)"
            end
        end
        !isempty(suffix) && (suffix = "@ " * suffix)
        return color, prefix, suffix
    end

    log_file = joinpath(dir_p, "execution.log")
    file_logger = Logging.ConsoleLogger(open(log_file, "w"), Logging.Debug, meta_formatter=logger_metafmt)
    #file_logger = LoggingExtras.MinLevelLogger(LoggingExtras.FileLogger(log_file), Logging.Debug) #print souce_info at each log line
    logger = LoggingExtras.TeeLogger(Logging.current_logger(), file_logger)

    Base.global_logger(logger)
end

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

function rm_files(dir::String, f)
    if isdir(dir)
        matches = filter(f, readdir(dir))
        paths = joinpath.(dir, matches)
        files_to_rm = filter(isfile, paths)
        foreach(rm, files_to_rm)
    end
end

function rm_non_prefixed(dir::String, prefix::String)
    rm_files(dir, !startswith(prefix))
end

function rm_prefixed(dir::String, prefix::String)
    rm_files(dir, startswith(prefix))
end

"""
Like Base.split() but returns a vector of String instead of a vector of SubString{String}
"""
function split_str(str::AbstractString, dlm; keepempty::Bool=true)
    return String.(split(str, dlm, keepempty=keepempty))
end

function split_with_space(str::String)
    result = String[];
    if length(str) > 0
        start_with_quote = startswith(str, "\"");
        buffer_quote = split(str, keepempty=false, "\"");
        i = 1;
        while i <= length(buffer_quote)
            if i > 1 || !start_with_quote
                str2 = buffer_quote[i];
                buffer_space = split(str2, keepempty=false);
                for str3 in buffer_space
                    push!(result, str3);
                end
                i += 1;
            end
            if i <= length(buffer_quote)
                push!(result, buffer_quote[i]);
                i += 1;
            end
        end
    end
    return result;
end

function is_different(a, b)
    return a != b
end
function is_different(a::Number, b::Number)
    return abs(a-b) >= 1e-09
end

