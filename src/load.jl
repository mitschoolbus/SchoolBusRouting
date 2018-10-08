###################################################
## load.jl
##     Loads benchmarks from Park, Tae and Kim (2011)
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

"""
    Convert weird coordinates from synthetic benchmarks to lat and lon
        Assumes a random center
"""
function parseCoordinates(x::Real, y::Real; center="Default")
    # convert weird units to meters centered at the correct place
    x = (x - 105_600) * 0.3048
    y = (y - 105_600) * 0.3048
    # convert planar coordinates to latitude and longitude at some arbitrary location
    clon, clat = getMapCenter(name=center)
    CENTER = LLA(clon, clat, 0.)
    point = LLAfromENU(CENTER, wgs84)(ENU(x, y, 0.))
    return LatLon(point.lat, point.lon)
end

"""
    Convert LatLon to x and y (ENU), given a center
"""
function convertLatLon(position::LatLon; center="Default")
    clon, clat = getMapCenter(name=center)
    CENTER = LLA(clon, clat, 0.)
    point = ENUfromLLA(CENTER, wgs84)(LLA(position.lat, position.lon, 0.))
    return point.e, point.n
end

"""
    Helper function to parse time from synthetic text files
"""
function parseTime(time)
    s = string(time)
    minutes = float(s[end-1:end]) * 60
    hours = float(s[1:end-2]) * 3600
    return hours+minutes
end

"""
    Load a tab-separated file containing the school data
"""
function loadSchoolsReduced(schoolsFileName::AbstractString,
                            maxEffect::Real=Inf,
                            randomStart::Bool=false, seed::Int=-1,
                            spreadStart::Bool=false)
    if seed < 0
        srand()
    else
        srand(seed)
    end
    schoolData  = CSV.read(schoolsFileName, delim="\t", DataFrame)

    if spreadStart
        arrivalTimes = spreadBellTimes(schoolData, maxEffect)
    end
    schools = School[]
    for i in 1:nrow(schoolData)
        id = length(schools) + 1
        originalId = get(schoolData[i, :ID])
        position = parseCoordinates(get(schoolData[i, :X]), get(schoolData[i, :Y]))
        dwelltime = 150.
        intervalStart = parseTime(get(schoolData[i, :AMEARLY]))
        intervalEnd = parseTime(get(schoolData[i, :AMLATE]))
        if randomStart # randomly select start time in allowed window
            starttime = intervalStart + (intervalEnd-intervalStart)*rand() + dwelltime
        elseif spreadStart
            starttime = arrivalTimes[i] + dwelltime
        else
            starttime = intervalStart + dwelltime
        end
        push!(schools, School(id, originalId, position, dwelltime, starttime))
    end
    return schools
end

function spreadBellTimes(schoolData::DataFrame, maxEffect::Real)
    intervalStart = [parseTime(get(schoolData[i,:AMEARLY])) for i=1:nrow(schoolData)]
    intervalEnd = [parseTime(get(schoolData[i,:AMLATE])) for i=1:nrow(schoolData)]
    model = Model(solver=GurobiSolver(OutputFlag=0))
    @variable(model, intervalStart[i] <= belltime[i=1:nrow(schoolData)] <= intervalEnd[i])
    # distances
    @variable(model, 0 <= d[i=1:nrow(schoolData), j=1:nrow(schoolData)] <= 
                     maximum(intervalEnd)-minimum(intervalStart))
    @constraint(model, [i=1:nrow(schoolData), j=1:nrow(schoolData);
                        0 < intervalStart[j] - intervalEnd[i] < maxEffect],
                d[i,j] <= belltime[j] - belltime[i])
    @objective(model, Max, sum(d))
    solve(model)
    return getvalue(belltime)
end

"""
    Create a yard in the center of the district, with 200 full buses
"""
function syntheticYards()
	return [Yard(1, parseCoordinates(105_600., 105_600.))]
end

"""
    Load bus stops with students
"""
function loadPreComputedStops(stopsFileName::AbstractString, schools::Vector{School})
    stopData = CSV.read(stopsFileName, delim="\t", DataFrame)
    schoolIdMap = Dict(school.originalId => school.id for school in schools)
    stops = [Stop[] for school in schools]
    for i = 1:nrow(stopData)
        originalId = get(stopData[i, :ID])
        schoolId = schoolIdMap[get(stopData[i,:EP_ID])]
        position = parseCoordinates(get(stopData[i,:X_COORD]), get(stopData[i,:Y_COORD]))
        nStudents = get(stopData[i,:STUDENT_COUNT])
        push!(stops[schoolId],
              Stop(length(stops[schoolId])+1, i, originalId, schoolId, position, nStudents))
    end
    return stops
end

"""
    Load synthetic benchmark dataset
"""
function loadSyntheticBenchmark(schoolsFile::AbstractString, stopsFile::AbstractString;
                                randomStart::Bool=false, seed::Int=-1,
                                spreadStart::Bool=false, maxEffect::Real=Inf)
	data = SchoolBusData()
    data.schools = loadSchoolsReduced(schoolsFile, maxEffect, randomStart, seed, spreadStart)
    data.yards = syntheticYards()
    data.stops = loadPreComputedStops(stopsFile, data.schools)
    # update parameters
    data.params.bus_capacity                         = 66
    data.params.max_time_on_bus                      = 2700.
    data.params.constant_stop_time                   = 19.
    data.params.stop_time_per_student                = 2.6
    data.params.velocity                             = 20 * 0.44704
    data.withBaseData = true
    return data
end
