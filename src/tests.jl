###################################################
## tests.jl
##      Test solution
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

"""
	Check feasibility of solution
"""
function test(data::SchoolBusData)
	if data.withRoutingScenarios
		for (schoolID, routeList) in enumerate(data.routes)
	        nStops = Set(collect(1:length(data.stops[schoolID])))
	        for (i, route) in enumerate(routeList)
	            @assert i == route.id "ID for school $schoolID, rte $i doesn't match position in array"
	            @assert !isempty(route.stops) "Route $i for school $schoolID is empty"
	            nRiders = sum(nStudents(data, schoolID, stop) for stop in route.stops)
	            @assert nRiders <= data.params.bus_capacity "Route $i (school $schoolID) is overfull"
	            t = traveltime(data, data.stops[schoolID][route.stops[end]], data.schools[schoolID])
	            maxT = maxTravelTime(data, data.stops[schoolID][route.stops[end]])
	            @assert t <= maxT "A student stays on the bus too long"
	            t += stopTime(data, data.stops[schoolID][route.stops[end]])
	            nextStopID = route.stops[end]
	            for stopID in route.stops[end-1:-1:1]
	                t += traveltime(data, data.stops[schoolID][stopID],
	                                data.stops[schoolID][nextStopID])
	                maxT = maxTravelTime(data, data.stops[schoolID][stopID])
	                @assert t <= maxT "A student stays on the bus too long"
	                t += stopTime(data, data.stops[schoolID][stopID])
	                nextStopID = stopID
	            end
	        end
	        for (i, scenario) in enumerate(data.scenarios[schoolID])
	        	@assert i == scenario.id "ID for school $schoolID, sc. $i doesn't match array position"
	        	covStops = Set(Int[])
	        	for j in scenario.routeIDs
	        		for stopId in routeList[j].stops
	        			@assert !(stopId in covStops) "Stop $stopId for school $schoolId visited twice"
	        			push!(covStops, stopId)
	        		end
	        	end
	        	@assert covStops == nStops "A stop for school $schoolId is not visited"
	        end
	    end
	end
	if data.withFinalBuses
		routesToCover = [Set(data.scenarios[i][data.usedScenario[i]].routeIDs)
                       for i = eachindex(data.schools)]
	    for (j, bus) in enumerate(data.buses)
	        @assert j == bus.id "Bus id does not match index in array"
			@assert !(isempty(bus.routes)) "Bus $(bus.id) serves no schools"
		    @assert (length(bus.routes) == length(bus.schools)) "Bus $(bus.id) has bad info"
		    @assert (length(Set(bus.schools)) == length(bus.schools)) "Bus $(bus.id) dupl. schools"
		    if length(bus.schools) > 1
		        for i = 1:(length(bus.schools)-1)
		            stopId = data.routes[bus.schools[i+1]][bus.routes[i+1]].stops[1]
		            @assert (data.schools[bus.schools[i]].starttime +
		                     traveltime(data, data.schools[bus.schools[i]],
		                                data.stops[bus.schools[i+1]][stopId]) +
		                     data.schools[bus.schools[i+1]].dwelltime <=
		                     data.schools[bus.schools[i+1]].starttime) "Infeasible school-to-school route"
		        end
		    end
		    for i = eachindex(bus.schools)
	            delete!(routesToCover[bus.schools[i]], bus.routes[i])
	        end
		end
		for i = eachindex(data.schools)
	        @assert isempty(routesToCover[i]) "School $i has a non-covered route"
	    end
	end
    println("Solution is feasible")
end
