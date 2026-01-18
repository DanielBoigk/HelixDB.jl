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
