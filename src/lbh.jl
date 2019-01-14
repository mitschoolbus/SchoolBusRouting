###################################################
## lbh.jl
##      Compute routing solution using location-based heuristic from Braca et al.
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

struct Itinerary
    "The schools cisited by our current itinerary"
	schools::Vector{Int}
    "The stops visited prior to each one of these school"
    stops::Vector{Vector{Int}}
    "The current occupancy of each segment"
    nStudents::Vector{Int}
    "Amount of extra time students at each stop can spend on bus"
    slacktimes::Vector{Vector{Float64}}
    "Amount of time students at each stop are already spending on bus"
    stoptimes::Vector{Vector{Float64}}
    "Length of each route"
    routetime::Vector{Float64}
end

"""
	Implements LBH
"""
function lbh(data::SchoolBusData)
	buses = Bus[]
	routes = [Route[] for school in data.schools]
    availableStops = [trues(length(data.stops[i])) for i=eachindex(data.stops)]
    while sum(sum(availableStops[i]) for i=eachindex(availableStops)) > 0
        # randomly select a starting stop (uniformly)
        schoolID, startingStopID = randomstop(availableStops)
        # create initial itinerary (select initial bus)
        current = initialItinerary(data, schoolID, startingStopID)
        availableStops[schoolID][startingStopID] = false
        while true
        	bestSchoolID = 0
            bestStopID = 0
            bestInsert = (-1, -1)
            bestCost = Inf
            for schoolID in eachindex(availableStops)
	            for stopID in collect(1:length(availableStops[schoolID]))[availableStops[schoolID]]
	                if undercapacity(data, current, schoolID, stopID)
	                    insertschool, insertstop, timeDiff = bestInsertion(data, schoolID,
                                                                           stopID, current)
	                    if timeDiff < bestCost
	                        bestCost = timeDiff
                            bestSchoolID = schoolID
	                        bestStopID = stopID
	                        bestInsert = (insertschool, insertstop)
	                    end
	                end
	            end
	        end
            if bestCost < Inf
                # insertion index in itinerary (doesn't correspond to ID numbers)
                insertschool, insertstop = bestInsert
                current = insert(data, current, bestSchoolID, bestStopID,
                                 insertschool, insertstop)
                availableStops[bestSchoolID][bestStopID] = false
            else
            	busschools = Int[]
            	busroutes = Int[]
                for (i, school) in enumerate(current.schools)
                	push!(routes[school], Route(length(routes[school]) + 1, current.stops[i]))
                	push!(busschools, school)
                	push!(busroutes, length(routes[school]))
                end
                randomyard = rand([yard.id for yard in data.yards])
                push!(buses, Bus(length(buses)+1, randomyard, busschools, busroutes))
                break
            end
        end
    end
    scenarios = [[Scenario(i, 1, collect(eachindex(routes[i])))] for i=eachindex(data.schools)]
    usedscenario = ones(Int, length(data.schools))
    return scenarios, routes, usedscenario, buses
end

"""
	Select a stop uniformly at random
"""
function randomstop(availableStops)
	ids = []
	for i=eachindex(availableStops), j=eachindex(availableStops[i])
		if availableStops[i][j]
			push!(ids, (i,j))
		end
	end
	return rand(ids)
end

"""
	Checks if insertion of a stop meets capacity constraints
"""
function undercapacity(data::SchoolBusData, current::Itinerary, school::Int, stop::Int)
	idx = findfirst(current.schools, school)
	if idx == 0 # school not yet visited
		return true
	else
		return (data.stops[school][stop].nStudents + current.nStudents[idx] <=
	                    data.params.bus_capacity)
	end
end

"""
	Find best place to insert a stop
"""
function bestInsertion(data::SchoolBusData,
                       schoolID::Int,
                       newStopID::Int, 
                       current::Itinerary)
	idx = findfirst(current.schools, schoolID)
    newStop = data.stops[schoolID][newStopID]
	if idx == 0
        # try inserting before any school starts
        bestTimeDiff = Inf
        insertId = -1
        isfeasible = (data.schools[schoolID].starttime + 
                      traveltime(data, data.schools[schoolID],
                                 data.stops[current.schools[1]][current.stops[1][1]]) +
                      current.routetime[1] + 
                      data.schools[current.schools[1]].dwelltime <=
                      data.schools[current.schools[1]].starttime)
        if isfeasible
            bestTimeDiff = stopTime(data, newStop) +
                           traveltime(data, newStop, data.schools[schoolID]) +
                           data.schools[schoolID].dwelltime +
                           traveltime(data, data.schools[schoolID],
                                      data.stops[current.schools[1]][current.stops[1][1]])
            insertId = 0
        end
        # try inserting between schools
        for i = 1:(length(current.schools) - 1)
            isfeasible = (data.schools[current.schools[i]].starttime +
                          traveltime(data, data.schools[current.schools[i]], newStop) +
                          stopTime(data, newStop) + 
                          traveltime(data, newStop, data.schools[schoolID]) +
                          data.schools[schoolID].dwelltime <=
                          data.schools[schoolID].starttime) &&
                         (data.schools[schoolID].starttime + 
                          traveltime(data, data.schools[schoolID],
                                     data.stops[current.schools[i+1]][current.stops[i+1][1]]) +
                          current.routetime[i+1] + 
                          data.schools[current.schools[i+1]].dwelltime <=
                          data.schools[current.schools[i+1]].starttime)
            if isfeasible
                timeDiff = traveltime(data, data.schools[current.schools[i]], newStop) +
                           stopTime(data, newStop) + 
                           traveltime(data, newStop, data.schools[schoolID]) +
                           data.schools[schoolID].dwelltime +
                           traveltime(data, data.schools[schoolID],
                                      data.stops[current.schools[i+1]][current.stops[i+1][1]])
                if timeDiff < bestTimeDiff
                    bestTimeDiff = timeDiff
                    insertId = i
                end
            end
        end
        # try inserting after the last school
        timeDiff = traveltime(data, data.schools[current.schools[end]], newStop) +
                   stopTime(data, newStop) + 
                   traveltime(data, newStop, data.schools[schoolID]) +
                   data.schools[schoolID].dwelltime
        isfeasible = (data.schools[current.schools[end]].starttime + timeDiff <=
                      data.schools[schoolID].starttime)
        if isfeasible && timeDiff < bestTimeDiff
            bestTimeDiff = timeDiff
            insertId = length(current.schools)
        end
        return insertId, -1, bestTimeDiff
    else
        school = data.schools[schoolID]
        bestTimeDiff = Inf
        insertId = -1
        # before first stop
        timeToNextStop = traveltime(data, newStop, data.stops[schoolID][current.stops[idx][1]])
        if idx > 1
            timeDiff = traveltime(data, data.schools[current.schools[idx-1]], newStop) +
                       timeToNextStop + stopTime(data, newStop) -
                       traveltime(data, data.schools[current.schools[idx-1]],
                                  data.stops[schoolID][current.stops[idx][1]])
        else
            timeDiff = timeToNextStop + stopTime(data, newStop)
        end
        isfeasible = (idx == 1 || data.schools[current.schools[idx-1]].starttime +
                      current.routetime[idx] + timeDiff + school.dwelltime <=
                      school.starttime) &&
                timeToNextStop + current.routetime[idx] <= maxTravelTime(data, newStop)
        if isfeasible
            bestTimeDiff = timeDiff
            insertId = 0
        end
        # between stops
        for i = 1:(length(current.stops[idx])-1)
            timeToNextStop = traveltime(data, newStop,
                                        data.stops[schoolID][current.stops[idx][i+1]])
            timeDiff = traveltime(data, data.stops[schoolID][current.stops[idx][i]], newStop) +
                       timeToNextStop -
                       traveltime(data, data.stops[schoolID][current.stops[idx][i]],
                                  data.stops[schoolID][current.stops[idx][i+1]]) +
                       stopTime(data, newStop)
            if timeDiff < bestTimeDiff
                isfeasible = timeDiff <= current.slacktimes[idx][i]
                isfeasible = isfeasible && (current.stoptimes[idx][i+1] + timeToNextStop +
                            stopTime(data, data.stops[schoolID][current.stops[idx][i+1]]) <=
                                            maxTravelTime(data, newStop))
                isfeasible = isfeasible && (idx == 1 ||
                                            data.schools[current.schools[idx-1]].starttime +
                      current.routetime[idx] + timeDiff + school.dwelltime <=
                      school.starttime)
                if isfeasible
                    bestTimeDiff = timeDiff
                    insertId = i
                end
            end
        end
        # after last stop
        timeDiff =  traveltime(data, data.stops[schoolID][current.stops[idx][end]], newStop) +
                    traveltime(data, newStop, school) + stopTime(data, newStop) -
                    traveltime(data, data.stops[schoolID][current.stops[idx][end]], school)
        isfeasible = timeDiff <= current.slacktimes[idx][end] &&
                     (traveltime(data, newStop, school) <= maxTravelTime(data, newStop)) &&
                     (idx == 1 || data.schools[current.schools[idx-1]].starttime +
                      current.routetime[idx] + timeDiff + school.dwelltime <=
                      school.starttime)
        if timeDiff < bestTimeDiff && isfeasible
            bestTimeDiff = timeDiff
            insertId = length(current.stops[idx])
        end
        return idx, insertId, bestTimeDiff
    end
end

"""
	Create the initial itinerary
"""
function initialItinerary(data::SchoolBusData, schoolID::Int, stopID::Int)
	timeOnBus = traveltime(data, data.stops[schoolID][stopID], data.schools[schoolID])
    nStudents = [data.stops[schoolID][stopID].nStudents]
    slackTimes = [[maxTravelTime(data, data.stops[schoolID][stopID]) - timeOnBus]]
    stopTimes = [[timeOnBus]]
    routetime = timeOnBus + stopTime(data, data.stops[schoolID][stopID])
    return Itinerary([schoolID], [[stopID]], nStudents, slackTimes, stopTimes, [routetime])
end

"""
    Actually perform insertion
"""
function insert(data::SchoolBusData, current::Itinerary, school::Int, stop::Int,
                insertschool::Int, insertstop::Int)
    if insertstop < 0
    	timeOnBus = traveltime(data, data.stops[school][stop], data.schools[school])
    	stoppingtime = stopTime(data, data.stops[school][stop])
    	newschools = vcat(current.schools[1:insertschool], school, 
    	                  current.schools[insertschool+1:end])
    	newstops = vcat(current.stops[1:insertschool], [[stop]], current.stops[insertschool+1:end])
    	nStudents = vcat(current.nStudents[1:insertschool], data.stops[school][stop].nStudents,
    	                 current.nStudents[insertschool+1:end])
    	slacktimes = vcat(current.slacktimes[1:insertschool],
    	                  [[maxTravelTime(data, data.stops[school][stop]) - timeOnBus]],
    	                  current.slacktimes[insertschool+1:end])
    	stoptimes = vcat(current.stoptimes[1:insertschool], [[timeOnBus]],
    	                 current.stoptimes[insertschool+1:end])
    	routetime = vcat(current.routetime[1:insertschool], timeOnBus+stoppingtime,
    	                 current.routetime[insertschool+1:end])
    else
    	newstop = data.stops[school][stop]
    	if insertstop == 0
    		nextstop = data.stops[school][current.stops[insertschool][1]]
        	newStopTimeOnBus = traveltime(data, newstop, nextstop) + stopTime(data, nextstop) +
                           	   current.stoptimes[insertschool][1] 				  
        	timeDiff = 0.
    	elseif insertstop == length(current.stops[insertschool])
    		previous = data.stops[school][current.stops[insertschool][end]]
	        newStopTimeOnBus = traveltime(data, newstop, data.schools[school])
	        timeDiff = newStopTimeOnBus + traveltime(data, previous, newstop) -
	                   traveltime(data, previous, data.schools[school])
    	else
    		previous = data.stops[school][current.stops[insertschool][insertstop]]
	        next = data.stops[school][current.stops[insertschool][insertstop+1]]
	        timeToNextStop = traveltime(data, newstop, next)
	        timeDiff = traveltime(data, previous, newstop) + timeToNextStop - 
	                   traveltime(data, previous, next)
	        newStopTimeOnBus = timeToNextStop + current.stoptimes[insertschool][insertstop+1] +
	        				   stopTime(data, next)
    	end
    	stoptimes  = (current.stoptimes)
    	slacktimes = (current.slacktimes)
    	nStudents  = (current.nStudents)
    	newstops   = (current.stops)
    	routetime  = (current.routetime)
    	stoptimes[insertschool] = vcat(current.stoptimes[insertschool][1:insertstop] + 
    	                               stopTime(data, newstop) + timeDiff,
                        			   [newStopTimeOnBus],
                        			   current.stoptimes[insertschool][insertstop+1:end])
	    slacktimes[insertschool] = vcat(current.slacktimes[insertschool][1:insertstop] -
	                                    stopTime(data, newstop) - timeDiff,
	                      				[maxTravelTime(data, newstop)] - newStopTimeOnBus,
	                      				current.slacktimes[insertschool][(insertstop+1):end])
	    for i=eachindex(slacktimes[insertschool])
	        if i > 1
	            slacktimes[insertschool][i] = min(slacktimes[insertschool][i-1],
	                                              slacktimes[insertschool][i])
	        end
	    end
	    newschools = current.schools
    	newstops[insertschool] = vcat(current.stops[insertschool][1:insertstop],
    	                              stop, current.stops[insertschool][insertstop+1:end])
    	nStudents[insertschool] += data.stops[school][stop].nStudents
    	routetime[insertschool] = stoptimes[insertschool][1] +
    							  stopTime(data, data.stops[school][newstops[insertschool][1]])
    end
    return Itinerary(newschools, newstops, nStudents, slacktimes, stoptimes, routetime)
end

"""
	Load LBH-computed routing solution
"""
function loadsolution!(data::SchoolBusData, scenarios::Vector{Vector{Scenario}},
					   routes::Vector{Vector{Route}}, usedscenario::Vector{Int},
					   buses::Vector{Bus})
	data.scenarios = scenarios
	data.routes = routes
	data.usedScenario = usedscenario
	data.buses = buses
	data.withRoutingScenarios = true
	data.withFinalBuses = true
	return data
end
