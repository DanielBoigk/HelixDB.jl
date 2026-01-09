# Helix.jl - HTTP Client Library for Julia

module Helix

using HTTP
using JSON

export Client, Query, Response
export WithTimeout, WithData, WithDest
export raw, asmap, scan

# Client structure
mutable struct Client
    host::String
    timeout::Float64
    
    function Client(host::String; timeout::Float64=10.0)
        # Ensure host ends with /
        if !endswith(host, "/")
            host = host * "/"
        end
        new(host, timeout)
    end
end

# Response structure
struct Response
    body::Vector{UInt8}
    status::Int
end

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

# Marshal input data to JSON bytes
function marshal_input(data)
    if isnothing(data)
        return UInt8['{', '}']
    end
    
    if data isa String
        # Validate JSON string
        try
            JSON.read(data)
            return Vector{UInt8}(data)
        catch
            throw(ArgumentError("Provided string is not valid JSON"))
        end
    end
    
    if data isa Vector{UInt8}
        # Validate JSON bytes
        try
            JSON.read(String(data))
            return data
        catch
            throw(ArgumentError("Provided byte array is not valid JSON"))
        end
    end
    
    if data isa AbstractArray && !(data isa AbstractDict)
        throw(ArgumentError("Input data cannot be an array; it must be a struct or dict to produce a key-value object"))
    end
    
    # Serialize to JSON
    try
        json_str = JSON.write(data)
        return Vector{UInt8}(json_str)
    catch e
        throw(ErrorException("Failed to marshal input data: $(e)"))
    end
end

# Query function
function Query(client::Client, endpoint::String; data=nothing)
    # Marshal input data
    json_data = try
        marshal_input(data)
    catch e
        throw(ErrorException("Failed to marshal input data: $(e)"))
    end
    
    # Build URL
    url = client.host * endpoint
    
    # Create headers
    headers = ["Content-Type" => "application/json"]
    
    # Make request with timeout
    try
        response = HTTP.post(
            url, 
            headers, 
            json_data;
            readtimeout=client.timeout,
            connect_timeout=client.timeout
        )
        
        return Response(response.body, response.status)
    catch e
        if e isa HTTP.ExceptionRequest.StatusError
            throw(ErrorException("$(e.status): $(String(e.response.body))"))
        else
            throw(ErrorException("Failed to send request: $(e)"))
        end
    end
end

# Convenience wrapper for WithData pattern
WithData(data) = data

end # module
