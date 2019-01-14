###################################################
## problem.jl
##     Problem data
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

@enum Metric MANHATTAN EUCLIDEAN

"""
    Set of parameters, with their documentation.
"""
mutable struct SchoolBusParameters
    "number of seats on a bus"
    bus_capacity::Int
    "maximum allowed time on bus"
    max_time_on_bus::Float64
    "constant stop time at bus stop"
    constant_stop_time::Float64
    "stop time per student"
    stop_time_per_student::Float64
    "distance metric"
    metric::Metric
    "vehicle speed"
    velocity::Float64
    SchoolBusParameters() = new()
end

"""
    Default set of parameters.
"""
function defaultParameters()
    params = SchoolBusParameters()
    params.bus_capacity                         = 66
    params.max_time_on_bus                      = 3600.
    params.constant_stop_time                   = 30.
    params.stop_time_per_student                = 5.
    params.velocity                             = 20 * 0.44704 # 20 mph
    params.metric                               = MANHATTAN
    return params
end

"""
    Contains a latitude and a longitude
"""
struct Point
    "the latitude"
    x::Float64
    "the longitude"
    y::Float64
end

"""
    Represents all the data needed for 1 school
"""
struct School
    "School Id, corresponds to the index in the array of schools"
    id::Int
    "Unique school identifier from data"
    originalId::Int
    "School position"
    position::Point
    "the bus dwell time (drop-off time)"
    dwelltime::Float64
    "School Start Time (in seconds from midnight): time at which buses finish drop-off"
    starttime::Float64
    "Time window start"
    start_tw::Float64
    "Time window end"
    end_tw::Float64
end
Base.show(io::IO, school::School) = print(io, "School $(school.id) - $(school.originalId)")

"""
    Represents the information about a bus yard.
"""
struct Yard
    "Yard id"
    id::Int
    "Yard location"
    position::Point
end
Base.show(io::IO, yard::Yard) = print(io, "Bus Yard $(yard.id)")

"""
    Represent a stop a bus has to make, can be a door to door student or a corner stop.
    This stop corresponds to one school.
"""
struct Stop
    "Unique id, within the stops of one school."
    id::Int
    "Unique id, within all the stops that are used"
    uniqueId::Int
    "Original id from data"
    originalId::Int
    "School that corresponds to the stop"
    schoolId::Int
    "Position"
    position::Point
    "Number of students"
    nStudents::Int
end

"""
    Data type contains a single routing scenario for one school
"""
struct Scenario
    "School"
    school::Int
    "Unique id for this school"
    id::Int
    "IDs of bus routes in this scenario"
    routeIDs::Vector{Int}
end

"""
    Object represents a single route
    By convention, stops are ordered from furthest to school to nearest to school (morning order)
"""
struct Route
    "Unique id of route"
    id::Int
    "List of stops for the route"
    stops::Vector{Int}
end

"""
    Object represents an actual bus
    Schools/routes are ordered in chronological order
"""
struct Bus
    "Unique id"
    id::Int
    "Yard of bus"
    yard::Int
    "List of schools served"
    schools::Vector{Int}
    "List of routes served"
    routes::Vector{Int}
end

"""
    Stores all information provided about the school bus problem
"""
mutable struct SchoolBusData
    params::SchoolBusParameters
    "If the object contains the base data"
    withBaseData::Bool
    "If routing scenarios are computed"
    withRoutingScenarios::Bool
    "If final buses are assigned"
    withFinalBuses::Bool

    # Base data
    "List of Schools"
    schools::Vector{School}
    "List of Bus Yards"
    yards::Vector{Yard}

    # Stops
    "List of Bus Stops for each school."
    stops::Vector{Vector{Stop}}

    # Routing Scenarios
    "List of scenarios"
    scenarios::Vector{Vector{Scenario}}
    "List of routes"
    routes::Vector{Vector{Route}}

    # Final bus info
    "Used scenario index"
    usedScenario::Vector{Int}
    "Final buses"
    buses::Vector{Bus}

    function SchoolBusData()
        data = new()
        data.params = defaultParameters()
        data.withBaseData = false
        data.withRoutingScenarios = false
        data.withFinalBuses = false
        return data
    end
end

function Base.show(io::IO, data::SchoolBusData)
    println(io, "School Bus Data")
    data.withBaseData && @printf(io, "- With %d schools: %.1f stops/school.\n",
                                 length(data.schools),
                                 mean(length(stoplist) for stoplist in data.stops))
    data.withRoutingScenarios && @printf(io, "- With routing scenarios computed: %.1f/school.\n",
                                mean(length(scenarioList) for scenarioList in data.scenarios))
    data.withFinalBuses && @printf(io, "- With %d buses assigned.\n", length(data.buses))
end

"""
    Update all school start times at once
"""
function updateStartTimes!(data::SchoolBusData, starttimes)
    data.schools = [School(school.id, school.originalId, school.position, school.dwelltime,
                           starttimes[i]) for (i, school) in enumerate(data.schools)]
    return data
end

getthreads() = haskey(ENV, "SLURM_JOB_CPUS_PER_NODE") ? parse(Int, ENV["SLURM_JOB_CPUS_PER_NODE"]) : 0
