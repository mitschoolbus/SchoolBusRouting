###################################################
## data/synthetic.jl
##     Creates a synthetic school-bus routing problem
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

"""
    Stores information about one student's walking time to a corner-stop.
"""
struct WalkingToStop
    "Id of the corresponding corner stop"
    cornerStopId::Int
    "Walking distance, in meters"
    distance::Float64
end

"""
    Represents all the data needed for 1 student
"""
struct Student
    "Student id, correspond to the index in the array of students"
    id::Int
    "Unique student identifier, does not change if students are re-ordered"
    originalId::Int
    "Student's house position"
    position::Point
    "id of school the student is assigned to"
    school::Int
    "whether the student is door to door"
    isD2D::Bool
    "Max walking distance, in meters, 0 if d2d"
    maxwalking::Float64
end

"""
    Represents a potential bus-stop (not a door to door one)
"""
struct CornerStop
    "Stop id"
    id::Int
    "Stop location"
    position::Point
end

"""
    Creates a synthetic school bus problem.
"""
function syntheticproblem(;
    nschools::Int=10,
    nyards::Int=1,
    districtsize::Float64 = 5000.,
    dwelltime::Float64 = 15.*60.,
    studentsperschool::Int = 120, 
    schoolrange=(1000., 8000.),
    studentspread::Float64=200., 
    studentclustering::Float64=0.85, 
    maxwalking::Float64=1610*0.5,
    d2dfraction::Float64=0.
    )
    data = SchoolBusData()

    districtshape = syntheticdistrictshape(districtsize)

    data.schools = synthetic_schools(nschools, districtshape, dwelltime)
    data.yards = synthetic_yards(districtshape, nyards)
    students = synthetic_students(data.schools, districtshape, studentsperschool,
                                  schoolrange, studentspread, studentclustering,
                                  maxwalking, d2dfraction)
    cornerStops = synthetic_cornerstops(students, districtshape, maxwalking)
    data.stops = simplestopassignment(data, students, cornerStops, 
                                      euclideanwalkingdistances(data, students, cornerStops))
    data.withBaseData = true

    data.params.bus_capacity                    = 65
    data.params.constant_stop_time              = 30.
    data.params.max_time_on_bus                 = 3600.
    data.params.stop_time_per_student           = 5.
    data.params.velocity                        = 35/3.6
    data.params.metric                          = EUCLIDEAN
    return data
end

"""
    Create the synthetic corner stops
    - Easy: generate one corner stop for each student, randomly within a radius around it.
"""
function synthetic_cornerstops(students, districtshape, maxwalking)
    stops = Vector{CornerStop}(length(students))

    for (i,student) in enumerate(students)
        centerposX, centerposY = (student.position.x, student.position.y)

        newpos = Point(Inf, Inf)
        while !isindistrict(districtshape, newpos)
            θ = 2π*rand()
            r = rand()+rand()
            r = maxwalking*min(r,2-r)

            newpos = Point(centerposX + r*cos(θ), centerposY + r*sin(θ))
        end
        position = newpos
        stops[i] = CornerStop(i, position)
    end
    return stops
end

"""
    Create synthetic students
    - So far all corner-stop students
"""
function synthetic_students(schools, districtshape, studentsperschool, schoolrange, studentspread, studentclustering, maxwalking, d2dfraction)
    studentsposition = synthetic_studentspositions(schools, districtshape, studentsperschool, schoolrange, studentspread, studentclustering)
    students = Student[]
    studentid = 1
    for (schoolid, positions) in enumerate(studentsposition), position in positions
        isD2D = rand() < d2dfraction
        push!(students,
        Student(studentid, studentid, position, schoolid, isD2D, maxwalking)
        )
        studentid += 1
    end
    students
end

"""
    Create the location of synthetic students and assign them to schoos
    - Schools have different range
    - students are "clustered"
"""
function synthetic_studentspositions(schools, districtshape, studentsperschool, schoolrange, studentspread, studentclustering)
    # total number of students is fixed
    totalstudents = studentsperschool * length(schools)
    # students are partitioned between schools
    schoolsplits = sort(shuffle(1:(totalstudents-1))[1:(length(schools)-1)])
    schoolsplits = vcat([0], schoolsplits, [totalstudents])
    studentsinschool = [schoolsplits[i+1] - schoolsplits[i] for i in 1:length(schools)]

    # school "range" i.e. typical student distance from school : random
    schoolrange = [schoolrange[1] + (schoolrange[2]-schoolrange[1])*rand() for i in 1:length(schools)]

    # generate the positions
    studentsposition = Vector{Point}[]

    function findfeasiblepositionaroundpoint(position, districtshape, range)
        centerposX, centerposY = position.x, position.y
        newpos = Point(Inf, Inf)
        while !isindistrict(districtshape, newpos)
            newpos = Point(centerposX +range * randn(), centerposY + range* randn())
        end
        return newpos
    end

    for school in schools
        push!(studentsposition, Point[])
        currentcluster = Point[]
        for i in 1:studentsinschool[school.id]
            if isempty(currentcluster)
                push!(currentcluster, findfeasiblepositionaroundpoint(school.position, districtshape, schoolrange[school.id]))
            else
                push!(currentcluster,
                      findfeasiblepositionaroundpoint(rand(currentcluster),
                                                      districtshape, studentspread))
            end
            if rand() > studentclustering
                append!(studentsposition[end],[point for point in currentcluster])
                currentcluster = Point[]
            end
        end
        append!(studentsposition[end],[point for point in currentcluster])
    end
    return studentsposition
end

"""
    Create synthetic yards and buses
    so far, very simple: a large number of full buses in each yard.
"""
function synthetic_yards(districtshape, nyards::Int)
    yards = Vector{Yard}(nyards)
    for i in 1:nyards
        yardposition = randomdistrictposition(districtshape)
        yards[i] = Yard(i, yardposition)
    end
    return yards
end

"""
    Create synthetic schools
"""
function synthetic_schools(nschools::Int, districtshape, dwelltime::Float64)
    # first generate the schools uniformly inside the district shape
    schoolpositions = [randomdistrictposition(districtshape) for i in 1:nschools]

    starttimes = randomstarttimes(nschools)

    schools = School[]
    minStartTime = 7.5 * 3600
    maxStartTime = 9.5 * 3600
    for i in 1:nschools
        push!(schools, School(
            i, i, schoolpositions[i], dwelltime,
            starttimes[i], minStartTime, maxStartTime
        ))
    end
    return schools
end

"""
    returns the shape of the district, a rotated cube centered on 0
"""
function syntheticdistrictshape(districtsize)
    return districtsize
end

"""
    return a uniformly random position in the district
"""
function randomdistrictposition(districtshape)
    x = districtshape*(rand()-0.5)
    y = districtshape*(rand()-0.5)
    return Point((x+y)/sqrt(2), (x-y)/sqrt(2))
end

"""
    returns true if the given position is in the district
"""
function isindistrict(districtshape, position)
    x,y = position.x, position.y
    return (-districtshape/2 <= (x+y)/sqrt(2) <= districtshape/2) && (-districtshape/2 <= (x-y)/sqrt(2) <= districtshape/2)
end

"""
    returns a random set of start times, given different schools
"""
function randomstarttimes(nschools::Int)
    return rand([7.5,8.5,9.5].*3600., nschools)
end

"""
    adds euclidean walking distance to a schoolbus problem
"""
function euclideanwalkingdistances(data::SchoolBusData, students::Vector{Student},
                                   cornerStops::Vector{CornerStop})
    walkingtostops = Vector{WalkingToStop}[WalkingToStop[] for s in students]

    for student in students
        if !student.isD2D
            for stop in cornerStops
                dist = euclideandistance(student.position, stop.position)
                if dist <= student.maxwalking
                    push!(walkingtostops[student.id], WalkingToStop(stop.id, dist))
                end
            end
        end
        sort!(walkingtostops[student.id], by=w->w.distance)
    end
    return walkingtostops
end

"""
    simple stop assignment (no limit on #students per stop)
"""
function simplestopassignment(data::SchoolBusData, students::Vector{Student},
                              cornerStops::Vector{CornerStop},
                              walkingtostops::Vector{Vector{WalkingToStop}};
                              λ::Real=1e4, args...)
    studentsinschool = [Int[] for school in data.schools]
    for student in students
        if !student.isD2D
            push!(studentsinschool[student.school], student.id)
        end
    end  
    studentstops = zeros(Int, length(students))
    for school in data.schools
        studentids = studentsinschool[school.id]

        if !isempty(studentids)
            stops  = Set{Int}(stop.cornerStopId for i in studentids for stop in walkingtostops[i])

            model = Model(solver=GurobiSolver(Threads=getthreads(), OutputFlag=0;args...))
            @variable(model, z[i in studentids, stop in walkingtostops[i]], Bin)
            # student i choose stop j

            @variable(model, usedStop[stopId in stops], Bin) # stops used

            @constraint(model, oneStopPerStudent[i in studentids],
                        sum(z[i,stop] for stop in walkingtostops[i]) == 1)

            @constraint(model, stopIsUsed[i in studentids, stop in walkingtostops[i]],
                        z[i,stop] <= usedStop[stop.cornerStopId])


            @objective(model, Min,
                    sum(usedStop[stopid] for stopid in stops) +
                λ * sum(z[i,stop] * stop.distance for i in studentids, stop in walkingtostops[i])
            )

            status = solve(model)

            for i in studentids, stop in walkingtostops[i]
                if getvalue(z[i, stop]) >= 0.5
                    studentstops[i] = stop.cornerStopId
                end
            end
        end
    end
    selectedbusstopsandstudents = Dict{Tuple{Int,Int}, Vector{Int}}()
    # (school, cornerStop) => students
    for (studentid, stopid) in enumerate(studentstops)
        students[studentid].isD2D && continue
        schoolid = students[studentid].school
        if haskey(selectedbusstopsandstudents, (schoolid, stopid))
            push!(selectedbusstopsandstudents[schoolid, stopid], studentid)
        else
            selectedbusstopsandstudents[schoolid, stopid] = [studentid]
        end
    end
    stops = Vector{Stop}[Stop[] for i in eachindex(data.schools)]
    # Will be used to create the unique stop id.
    uniqueid = 1
    for (schoolid,stopid) in sort(collect(keys(selectedbusstopsandstudents)))
        stopstudents = selectedbusstopsandstudents[schoolid, stopid]
        push!(stops[schoolid],
            Stop(length(stops[schoolid])+1, uniqueid, stopid, schoolid,
                 cornerStops[stopid].position, length(stopstudents))
        )
        uniqueid += 1
    end
    for student in students
        if student.isD2D
            push!(stops[student.school],
                Stop(length(stops[student.school])+1, uniqueid, 0, student.school,
                     student.position, 1)
            )
            uniqueid += 1
        end
    end
    return stops
end
