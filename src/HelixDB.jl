module HelixDB

using HTTP
using JSON
using Serde

export Client, Query, Response
export WithTimeout, WithData, WithDest
export raw, asmap, scan

include("Structs.jl")

include("Response.jl")

include("Query.jl")


WithData(data) = data

end # module
