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
