###################################################
## scenarios.jl
##      Compute routing solutions for a single school
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

"""
    The main euclidian traveltime function.
    Select the time that is the closest to `time` and return the euclidian travel-time
    for the corresponding speed.
"""
function traveltime(data::SchoolBusData, o::LatLon, d::LatLon)
    return distance(o,d) / data.params.velocity
end

"""
    Distance between two latlon points, in meters
"""
function distance(o::LatLon, d::LatLon)
    dLat = (d.lat - o.lat) * π / 180.0
    dLon = (d.lon - o.lon) * π / 180.0
    lat1 = (o.lat) * π / 180.0
    lat2 = (d.lat) * π / 180.0
    a = sin(dLat/2)^2 + sin(dLon/2)^2 * cos(lat1) * cos(lat2)
    2.0 * atan2(sqrt(a), sqrt(1-a)) * 6373.0 * 1000
end

traveltime(data::SchoolBusData, o::Yard, d::Stop) = traveltime(data, o.position, d.position)
traveltime(data::SchoolBusData, o::School, d::Stop) = traveltime(data, o.position, d.position)
traveltime(data::SchoolBusData, o::Stop, d::Stop) = traveltime(data, o.position, d.position)
traveltime(data::SchoolBusData, o::Stop, d::School) = traveltime(data, o.position, d.position)
traveltime(data::SchoolBusData, o::School, d::Yard) = traveltime(data, o.position, d.position)
traveltime(data::SchoolBusData, o::Yard, d::School) = traveltime(data, o.position, d.position)
traveltime(data::SchoolBusData, o::Stop, d::Yard) = traveltime(data, o.position, d.position)

"""
    Get number of students at the stop
"""
nStudents(data::SchoolBusData, stop::Stop) = stop.nStudents
nStudents(data::SchoolBusData, school::Int, stop::Int) = data.stops[school][stop].nStudents

"""
    Get time that bus must remain at stop
"""
function stopTime(data::SchoolBusData, stop::Stop)
    return data.params.constant_stop_time + data.params.stop_time_per_student * stop.nStudents
end

"""
    Get the maximum allowed travel time for a given bus stop
"""
function maxTravelTime(data::SchoolBusData, stop::Stop)
	return data.params.max_time_on_bus
end

"""
    The current state of the greedy algorithm
    Contains:
        - the current route
        - an occupancy object that tells us how many students are currently on the bus
        - for each stop, the amount of extra time we can leave the students on the bus
        - for each stop, the current time spent on the bus
        - the total service time of the route (including time of first stop)
"""
struct GreedyState
    "the current route"
    route::Route
    "the current occupancy"
    nStudents::Int
    "amount of extra time students at each stop can spend on bus"
    slackTimes::Vector{Float64}
    "amount of time students at each stop are already spending on bus"
    stopTimes::Vector{Float64}
    "total time of current route"
    routeTime::Float64
end

"""
    Greedy single-school routing heuristic
    Args:
        - the data
        - the ID of the school
        - the maximum time allowed on a route
        - the penalty (in seconds) for adding D2D students to routes
    Returns:
        - all routes for the school as a Vector{Route}
"""
function greedy(data::SchoolBusData, schoolID::Int, maxRouteTime::Float64)
    routes = Route[]
    availableStops = trues(length(data.stops[schoolID]))
    while sum(availableStops) > 0
        # randomly select a starting stop
        startingStopID = rand((1:length(availableStops))[availableStops])
        # create initial route (select initial bus)
        currentState = initialRoute(data, schoolID, startingStopID, length(routes)+1)
        availableStops[startingStopID] = false
        while true
            bestStopID = 0
            bestInsertId = -1
            bestTimeDiff = Inf
            for stopID in collect(1:length(availableStops))[availableStops]
                if (data.stops[schoolID][stopID].nStudents + currentState.nStudents <=
                	data.params.bus_capacity)
                    insertId, timeDiff = bestInsertion(data, schoolID, stopID, currentState,
                                                       maxRouteTime)
                    if timeDiff < bestTimeDiff
                        bestTimeDiff = timeDiff
                        bestStopID = stopID
                        bestInsertId = insertId
                    end
                end
            end
            if bestTimeDiff < Inf
                currentState = buildRoute(data, currentState, schoolID, bestStopID,
                                          bestInsertId)
                availableStops[bestStopID] = false
            else
                push!(routes, currentState.route)
                break
            end
        end
    end
    return routes
end

"""
    Get total travel time difference when adding stop to the route, together with
        a "cost" of how good this insertion is.
    The cost is equal to the total amount of time by which this insertion
        increases the length of the route, not including stop time
    Args:
        - data          : the data object, assumes it has the stops computed
        - schoolID      : the school we are routing
        - newStopID     : the stop we are trying to insert
        - cs            : the current GreedyState
        - maxRouteTime  : the maximal allowed length of the route
    Returns:
        - insertID      : where we would optimally insert it
        - bestTimeDiff  : the optimal time difference imposed on the route
"""
function bestInsertion(data::SchoolBusData,
                       schoolID::Int,
                       newStopID::Int, 
                       cs::GreedyState,
                       maxRouteTime::Float64)
    newStop = data.stops[schoolID][newStopID]
    school = data.schools[schoolID]
    bestTimeDiff = Inf
    insertId = -1
    # before first stop
    timeDiff = traveltime(data, newStop, data.stops[schoolID][cs.route.stops[1]])
    totTime = timeDiff + cs.routeTime + stopTime(data, newStop)
    if (totTime - stopTime(data, newStop) <= maxTravelTime(data, newStop) &&
                totTime <= maxRouteTime)
        bestTimeDiff = timeDiff
        insertId = 0
    end
    # between stops
    for i = 1:(length(cs.route.stops)-1)
        timeToNextStop = traveltime(data, newStop, data.stops[schoolID][cs.route.stops[i+1]])
        timeDiff = traveltime(data, data.stops[schoolID][cs.route.stops[i]], newStop) +
                   timeToNextStop -
                   traveltime(data, data.stops[schoolID][cs.route.stops[i]],
                      data.stops[schoolID][cs.route.stops[i+1]])
        if timeDiff < bestTimeDiff
            totTime = timeDiff + cs.routeTime + stopTime(data, newStop)
            # check feasibility for all stops preceding this one
            isFeasible = (timeDiff + stopTime(data, newStop) <= cs.slackTimes[i])
            # check feasibility for the potential new stop
            isFeasible = isFeasible && (cs.stopTimes[i+1] + timeToNextStop +
                                        stopTime(data, 
                                                 data.stops[schoolID][cs.route.stops[i+1]]) <=
                                        maxTravelTime(data, newStop))
            isFeasible = isFeasible && totTime <= maxRouteTime
            if isFeasible
                bestTimeDiff = timeDiff
                insertId = i
            end
        end
    end
    # after last stop
    timeDiff =  traveltime(data, data.stops[schoolID][cs.route.stops[end]], newStop) +
                traveltime(data, newStop, school) -
                traveltime(data, data.stops[schoolID][cs.route.stops[end]], school)
    if timeDiff < bestTimeDiff
        totTime = timeDiff + cs.routeTime + stopTime(data, newStop)
        isFeasible = timeDiff + stopTime(data, newStop) <= cs.slackTimes[end] && 
                        (traveltime(data, newStop, school) <= maxTravelTime(data, newStop))
        isFeasible = isFeasible && totTime <= maxRouteTime
        if isFeasible
            bestTimeDiff = timeDiff
            insertId = length(cs.route.stops)
        end
    end

    return insertId, bestTimeDiff
end

"""
    Given new stop ID and current route/GreedyState, update route
    Args:
        - data          : the data object, assumes it has the stops computed
        - cs            : the current GreedyState
        - schoolID      : the school we are routing
        - newStopID     : the stop we are inserting
        - insertID      : where we insert it
    Returns:
        - a new GreedyState with the updated route
"""
function buildRoute(data::SchoolBusData,
                    cs::GreedyState,
                    schoolID::Int,
                    newStopID::Int,
                    insertID::Int)
    newStop = data.stops[schoolID][newStopID]
    school = data.schools[schoolID]
    if insertID == 0 # at the beginning
        nextStop = data.stops[schoolID][cs.route.stops[1]]
        newStopTimeOnBus = traveltime(data, newStop, nextStop) +
                           cs.stopTimes[1] + stopTime(data,nextStop)
        timeDiff = 0.
    elseif insertID == length(cs.route.stops) # at the end
        previousStop = data.stops[schoolID][cs.route.stops[end]] # last stop on route
        newStopTimeOnBus = traveltime(data, newStop, school) # time from new stop to school
        timeDiff = newStopTimeOnBus + 
                   traveltime(data, previousStop, newStop) -
                   traveltime(data, previousStop, school)
    else # in the middle
        previousStop = data.stops[schoolID][cs.route.stops[insertID]]
        nextStop = data.stops[schoolID][cs.route.stops[insertID+1]]
        timeToNextStop = traveltime(data, newStop, nextStop)
        timeDiff = traveltime(data, previousStop, newStop) +
                   timeToNextStop - 
                   traveltime(data, previousStop, nextStop)
        newStopTimeOnBus = timeToNextStop + cs.stopTimes[insertID+1] + stopTime(data, nextStop)
    end
    newStopTimes = vcat(cs.stopTimes[1:insertID] + stopTime(data, newStop) + timeDiff,
                        [newStopTimeOnBus],
                        cs.stopTimes[(insertID+1):end])
    newStops = vcat(cs.route.stops[1:insertID], [newStopID], cs.route.stops[(insertID+1):end])
    newSlackTimes = vcat(cs.slackTimes[1:insertID] - stopTime(data, newStop) - timeDiff,
                         [maxTravelTime(data, newStop)] - newStopTimeOnBus,
                         cs.slackTimes[(insertID+1):end])
    # fix slack time property
    for i=eachindex(newSlackTimes)
        if i > 1
            newSlackTimes[i] = min(newSlackTimes[i-1], newSlackTimes[i])
        end
    end
    routeTime = newStopTimes[1] + stopTime(data, data.stops[schoolID][newStops[1]])
    return GreedyState(Route(cs.route.id, newStops),
                       cs.nStudents + newStop.nStudents,
                       newSlackTimes, newStopTimes, routeTime)
end

"""
    Create initial route for greedy
    Args:
        - data          : the data object, assumes it has the stops computed
        - schoolID      : the school we are routing
        - stopID        : the stop we start with
        - routeID       : the ID of the route we are creating
    Returns a GreedyState object
"""
function initialRoute(data::SchoolBusData,
                      schoolID::Int,
                      stopID::Int,
                      routeID::Int)
    timeOnBus = traveltime(data, data.stops[schoolID][stopID], data.schools[schoolID])
    nStudents = data.stops[schoolID][stopID].nStudents
    slackTimes = [maxTravelTime(data, data.stops[schoolID][stopID]) - timeOnBus]
    stopTimes = [timeOnBus]
    routeTime = timeOnBus + stopTime(data, data.stops[schoolID][stopID])
    return GreedyState(Route(routeID, [stopID]), nStudents, slackTimes, stopTimes, routeTime)
end

"""
    Returns the sum of each student's travel times on this route
"""
function sumIndividualTravelTimes(data::SchoolBusData, schoolID::Int, r::Route)
    allStops = data.stops[schoolID]
    numStops = length(r.stops)
    t = traveltime(data, allStops[r.stops[numStops]], data.schools[schoolID]) * numStops
    while numStops > 1
        t += (traveltime(data, allStops[r.stops[numStops-1]], allStops[r.stops[numStops]]) +
              stopTime(data, allStops[r.stops[numStops]])) * (numStops - 1)
        numStops -= 1
    end
    return t
end
function sumIndividualTravelTimes(data::SchoolBusData, schoolID::Int,
								  routes::Vector{Route})
    return sum(sumIndividualTravelTimes(data, schoolID, route) for route in routes)
end

"""
    Returns the total travel time from the time the first student enters the bus to the time of pickup/dropoff in school
"""
function serviceTime(data::SchoolBusData, schoolID::Int, r::Route)
    allStops = data.stops[schoolID]
    numStops = length(r.stops)
    t = traveltime(data, allStops[r.stops[numStops]], data.schools[schoolID])
    while numStops > 1
        t += (traveltime(data, allStops[r.stops[numStops-1]], allStops[r.stops[numStops]]) +
              stopTime(data, allStops[r.stops[numStops]]))
        numStops -= 1
    end
    t += stopTime(data, allStops[r.stops[1]])
    return t
end


"""
    Simple route representation : just list of IDs and associated cost
"""
struct FeasibleRoute
    "The list of stop ids"
    stopIds::Vector{Int}
    "The cost associated with the route"
    cost::Float64
end
function FeasibleRoute(data::SchoolBusData, schoolID::Int, r::Route)
    return FeasibleRoute(r.stops, sumIndividualTravelTimes(data, schoolID, r))
end

"""
    Stores a list of routes in a way that makes column generation easy
"""
struct FeasibleRouteSet
    "The list of FeasibleRoutes available"
    list::Vector{FeasibleRoute}
    "The set of stopIds list (one for each route)"
    set::Set{Vector{Int}}
    "For each stop, the index of the routes in the list that go through this stop"
    atStop::Vector{Vector{Int}}

    FeasibleRouteSet(data::SchoolBusData, schoolID::Int) =
        new(FeasibleRoute[], Set{Vector{Int}}(), [Int[] for i = 1:length(data.stops[schoolID])])
end

"""
    Generate N random greedy solutions, and combines them smartly to get the best
    possible solution.
"""
function greedyCombined(data::SchoolBusData,
                        schoolID::Int,
                        N::Int,
                        maxRouteTimeLower::Float64,
                        maxRouteTimeUpper::Float64,
                        λ::Float64,
                        env::Gurobi.Env=Gurobi.Env();
                        args...)
    routeList = generateRoutes(data, schoolID, N, maxRouteTimeLower, maxRouteTimeUpper)
    routes = FeasibleRouteSet(data, schoolID)
    addRoute!(routes, routeList)
    selectedRoutes = bestRoutes(data, schoolID, routes, λ, env; args...)
    return buildSolution(data, schoolID, routes, selectedRoutes)
end
function greedyCombined(data::SchoolBusData,
                        schoolID::Int,
                        startRoutes::Vector{Route},
                        N::Int,
                        maxRouteTimeLower::Float64,
                        maxRouteTimeUpper::Float64,
                        λ::Float64,
                        env::Gurobi.Env=Gurobi.Env();
                        args...)
    routeList = generateRoutes(data, schoolID, N, maxRouteTimeLower, maxRouteTimeUpper)
    routes = FeasibleRouteSet(data, schoolID)
    addRoute!(routes, routeList)
    addRoute!(routes, collect(FeasibleRoute(data, schoolID, r) for r in startRoutes))
    selectedRoutes = bestRoutes(data, schoolID, routes, λ, env; args...)
    return buildSolution(data, schoolID, routes, selectedRoutes)
end

"""
    Same as greedy combined, but iterates it to keep improving the best solution
"""
function greedyCombinedIterated(data::SchoolBusData,
                                schoolID::Int,
                                maxRouteTimeLower::Float64,
                                maxRouteTimeUpper::Float64,
                                nGreedy::Int,
                                nIteration::Int,
                                λ::Float64;
                                verbose::Bool=false,
                                args...)
    env = Gurobi.Env()
    routes = greedy(data, schoolID, Inf)
    verbose && @printf("Iteration 0: %d buses, %2.fs\n", length(routes),
                        sumIndividualTravelTimes(data, schoolID, routes))
    for i=1:nIteration
        routes = greedyCombined(data, schoolID, routes, nGreedy,
                                maxRouteTimeLower, maxRouteTimeUpper, λ, env; args...)
        verbose && @printf("Iteration %d: %d buses, %2.fs\n", i, length(routes),
                           sumIndividualTravelTimes(data, schoolID, routes))
    end
    gc()
    return routes
 end

"""
    Add feasible route to a feasible set
"""
function addRoute!(routes::FeasibleRouteSet, newRoute::FeasibleRoute)
    if ! (newRoute.stopIds in routes.set)
        push!(routes.set, newRoute.stopIds)
        push!(routes.list, newRoute)
        newRouteId = length(routes.list)
        for stopId in newRoute.stopIds
            push!(routes.atStop[stopId], newRouteId)
        end
    end
end

"""
    Add list of feasible routes to a feasible set
"""
function addRoute!(routes::FeasibleRouteSet, newRoutes::Vector{FeasibleRoute})
    for r in newRoutes
        addRoute!(routes, r)
    end
end


"""
    Generate N sets of Routes using the greedy heuristic.
"""
function generateRoutes(data::SchoolBusData,
                        schoolID::Int,
                        N::Int,
                        maxRouteTimeLower::Float64=Inf,
                        maxRouteTimeUpper::Float64=Inf)
    routes = FeasibleRoute[]
    for i in 1:N
        if maxRouteTimeLower < Inf
            maxTime = (maxRouteTimeUpper - maxRouteTimeLower) * rand() + maxRouteTimeLower
        else
            maxTime = Inf
        end
        singleRoutes = greedy(data, schoolID, maxTime)
        append!(routes, [FeasibleRoute(data, schoolID,route) for route in singleRoutes])
    end
    return routes
end

"""
    Solves the routing problem given a set of routes. (MIP)
"""
function bestRoutes(data::SchoolBusData, schoolID::Int, routes::FeasibleRouteSet,
                    λ::Float64, env::Gurobi.Env; args...)
    model = Model(solver=GurobiSolver(env, Threads=getthreads(); args...))

    # The binaries, whether we choose the routes
    @variable(model, r[k in 1:length(routes.list)], Bin)
    # Minimize the number of buses first, then the travel time
    @objective(model, Min, sum(r[k] * (λ + routes.list[k].cost) for k in 1:length(routes.list)))
    # At least one route per stop
    @constraint(model, stopServed[i in 1:length(data.stops[schoolID])],
        sum(r[k] for k in routes.atStop[i]) >= 1)
    solve(model)
    selectedRoutes = [k for k in 1:length(routes.list) if getvalue(r[k]) >= 0.5]
    return selectedRoutes
end

"""
    Given a covering list of FeasibleRoutes, create correct route object
"""
function buildSolution(data::SchoolBusData, schoolID::Int,
                       routeSet::FeasibleRouteSet, selectedRoutes::Vector{Int})
    routes = copy(routeSet.list[selectedRoutes])
    routesAtStop = Vector{Int}[Int[] for s in data.stops[schoolID]]
    for (routeId,r) in enumerate(routes)
        for stopId in r.stopIds
            push!(routesAtStop[stopId], routeId)
        end
    end
    for (stopId,intersectingRoutes) in enumerate(routesAtStop)
        if length(intersectingRoutes) > 1
            newRoutes = splitRoutes(data, schoolID, routes[intersectingRoutes], stopId)
            for (i, routeId) in enumerate(intersectingRoutes)
                routes[routeId] = newRoutes[i]
            end
        end
    end
    return [Route(i, fr.stopIds) for (i, fr) in enumerate(routes)]
end

"""
    When several routes intersect in stopId, choose the best one to serve the stopId
    and remove the others
"""
function splitRoutes(data::SchoolBusData, schoolID::Int,
                     routes::Vector{FeasibleRoute}, stopId::Int)
    costs = collect(deletionCost(data, schoolID, route, stopId) for route in routes)
    selectedRoute = indmax(costs)
    for (routeId, route) in enumerate(routes)
        if selectedRoute != routeId
            newRouteIds = collect(s for s in route.stopIds if s != stopId)
            routes[routeId] = FeasibleRoute(newRouteIds, route.cost + costs[routeId])    
        end
    end
    return routes
end

"""
    Cost of removing a stop from a route (usually negative)
    The cost is just the difference between the old travel time and the newStop
"""
function deletionCost(data::SchoolBusData, schoolID::Int,
                      route::FeasibleRoute, stopId::Int)
    stop = findfirst(route.stopIds, stopId)
    length(route.stopIds) <= 1 && error("The route should at least have two stops")
    stops = data.stops[schoolID]
    school = data.schools[schoolID]
    # remove travel time of that particular stop
    cost = 0.
    for id = stop:(length(route.stopIds)-1)
        cost -= traveltime(data, stops[route.stopIds[id]], stops[route.stopIds[id+1]])
        cost -= stopTime(data, stops[route.stopIds[id+1]])
    end
    cost -= traveltime(data, stops[route.stopIds[end]], school)
    # remove travel time effect on other stops
    if stop == length(route.stopIds)
        cost -= (traveltime(data, stops[route.stopIds[stop-1]], stops[stopId]) +
                 traveltime(data, stops[stopId], school) +
                 stopTime(data, stops[stopId]) -
                 traveltime(data, stops[route.stopIds[stop-1]], school)) *
                (length(route.stopIds) - 1)
    elseif stop > 1
        cost -= (traveltime(data, stops[route.stopIds[stop-1]], stops[stopId]) +
                 traveltime(data, stops[stopId], stops[route.stopIds[stop+1]]) +
                 stopTime(data, stops[stopId]) -
                 traveltime(data, stops[route.stopIds[stop-1]], stops[route.stopIds[stop+1]]))*
                (stop - 1)
    end
    return cost
end

"""
    Contains the parameters that were used to compute a particular scenario
"""
struct ScenarioParameters
    "Maximum time of routes - lower end of interval"
    maxRouteTimeLower::Float64
    "Maximum time of routes - upper end of interval"
    maxRouteTimeUpper::Float64
    "Number of greedy solutions optimized over"
    nGreedy::Int
    "Tradeoff parameter in optimization"
    λ::Float64
    "Number of iterations for greedy combined iterated"
    nIterations::Int
end
"""
    Constructor for ScenarioParameters, with keyword parameters for readability
"""
function ScenarioParameters(;maxRouteTimeLower=Inf,
                            maxRouteTimeUpper=Inf,
                            nGreedy::Int=10,
                            λ=5e3,
                            nIterations::Int=10)
    return ScenarioParameters(maxRouteTimeLower, maxRouteTimeUpper, nGreedy, λ, nIterations)
end

"""
	Compute scenario
"""
function getscenario(data, scenarioinfo)
    school, scenarioid, params = scenarioinfo
    routes = greedyCombinedIterated(data, school.id,
                                    params.maxRouteTimeLower, params.maxRouteTimeUpper,
                                    params.nGreedy, params.nIterations, params.λ;
                                    verbose=false, OutputFlag=0, TimeLimit=300)
    return Scenario(school.id, scenarioid, collect(eachindex(routes))), routes
end

"""
	Compute multiple scenarios
"""
function computescenarios(data, params)
    tocompute = shuffle!(vec([(school,paramid,param) for school in data.schools, (paramid,param) in enumerate(params)]))
    results = Tuple{Scenario,Vector{Route}}[]
    @showprogress for scenarioinfo in tocompute
        push!(results, getscenario(data, scenarioinfo))
    end
    return results
end
function computescenariosparallel(data, params)
    tocompute = shuffle!(vec([(school,paramid,param) for school in data.schools, (paramid,param) in enumerate(params)]))
    results = Tuple{Scenario,Vector{Route}}[]
    results = pmap(x->getscenario(data,x), tocompute)
    return results
end

"""
	Put the scenarios together
"""
function loadroutingscenarios!(data, scenariolist)
    scenarios = [Scenario[] for school in data.schools]
    routes = [Route[] for school in data.schools]
    ids = vec([(scenario.school, scenario.id) for (scenario, routelist) in scenariolist])

    for k in sortperm(ids)
    	(scenario, routelist) = scenariolist[k]
        for (i,route) in enumerate(routelist)
            idx = findfirst(x -> x.stops == route.stops, routes[scenario.school])
            if idx == 0 # need to add new route and update its id
                scenario.routeIDs[i] = length(routes[scenario.school]) + 1
                push!(routes[scenario.school],
                      Route(length(routes[scenario.school]) + 1, route.stops))
            else # need to update reference in the scenario
                scenario.routeIDs[i] = idx
            end
        end
        push!(scenarios[scenario.school], scenario)
    end
    data.scenarios = scenarios
    data.routes = routes
    data.withRoutingScenarios = true
    return data
end
