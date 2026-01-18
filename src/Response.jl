
# Get raw response body
raw(r::Response) = r.body

# Convert response to dictionary
function asmap(r::Response)
    try
        return JSON.read(String(r.body), Dict{String, Any})
    catch e
        throw(ErrorException("Failed to parse JSON response: $(e)"))
    end
end

# Scan response into destinations
function scan(r::Response, dest)
    # Single argument - direct unmarshal
    try
        data = JSON.read(String(r.body))
        _copy_to_dest!(dest, data)
    catch e
        throw(ErrorException("Failed to scan response: $(e)"))
    end
end

function scan(r::Response, fields::Pair{String, T}...) where T
    # Multiple field extractions
    try
        data = JSON.read(String(r.body), Dict{String, Any})

        for (fieldname, dest) in fields
            if !haskey(data, fieldname)
                throw(ErrorException("Field \"$(fieldname)\" not found in response"))
            end

            _copy_to_dest!(dest, data[fieldname])
        end
    catch e
        if isa(e, ErrorException) && contains(e.msg, "not found")
            rethrow(e)
        end
        throw(ErrorException("Failed to scan response: $(e)"))
    end
end

# Helper to copy data to destination
function _copy_to_dest!(dest::Ref{T}, data) where T
    dest[] = convert(T, data)
end

function _copy_to_dest!(dest::AbstractDict, data)
    empty!(dest)
    merge!(dest, data)
end

function _copy_to_dest!(dest::AbstractVector, data)
    empty!(dest)
    append!(dest, data)
end

# Helper for WithDest syntax
WithDest(fieldname::String, dest) = fieldname => dest
