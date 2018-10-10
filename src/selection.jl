###################################################
## selection.jl
##      Build graph for scenario-based network flow method to solve full problem
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

"""
    Represents a node in scenario graph
    Required attributes:
        - id::Int           : unique reference of node
"""
abstract type ScenarioNode end

"""
    Node in scenario graph, represents buses arriving at the beginning of a route for a school
"""
struct ArrivalNode <: ScenarioNode
    id::Int

    "School associated with this node"
    school::Int
    "Route corresponding to the node"
    route::Route
    "Total service time of route"
    serviceTime::Float64
    "Scenario number"
    scenario::Int
end

"""
    Node in scenario graph, represents buses departing from a school
"""
struct DepartureNode <: ScenarioNode
    id::Int

    "School associated with this node"
    school::Int
    "Capacity, i.e. number of buses that can leave"
    capacity::Int
    "Scenario number"
    scenario::Int
end

"""
    Node in scenario graph, represents a bus yard
"""
struct YardNode <: ScenarioNode
    id::Int

    "Yard associated with this node"
    yard::Int
end

"""
    represents graph of scenarios for schools (master problem)
"""
mutable struct ScenarioGraph
    "graph object"
    graph::DiGraph
    "list of nodes"
    nodes::Vector{ScenarioNode}
    "dictionary mapping node type to node ids"
    nodeTypes::Dict{Symbol,Vector{Int}}
    "dictionary mapping pairs of nodes to costs"
    costs::Dict{Tuple{Int,Int}, Float64}
    "number of scenarios per school"
    numScenarios::Vector{Int}
end

"""
    Assumes the scenarios have already been computed in the data
    Builds ScenarioGraph using this input
"""
function buildScenarioGraph(data::SchoolBusData)
    if !data.withRoutingScenarios
        error("Cannot compute scenario graph without scenarios")
    end
    nodes = ScenarioNode[]
    nodeTypes = Dict(elt => Int[] for elt in [:YardNode, :ArrivalNode, :DepartureNode])
    # get the yard nodes
    yardNodes, currentNodeId = getYardNodes!(data, nodeTypes)
    append!(nodes, yardNodes)
    numScenarios = [length(data.scenarios[sID]) for sID=eachindex(data.schools)]
    for schoolID = eachindex(data.schools)
        for scenarioNum = 1:numScenarios[schoolID]
            schoolNodes, currentNodeId = getSchoolScenarioNodes!(data, schoolID,
                                                                 currentNodeId, scenarioNum,
                                                                 nodeTypes)
            append!(nodes, schoolNodes)
        end
    end
    graph = DiGraph(length(nodes))
    costs = Dict{Tuple{Int,Int}, Float64}()
    possibleEdgeTypes = [(:DepartureNode, :ArrivalNode), (:DepartureNode, :YardNode),
                         (:ArrivalNode, :DepartureNode), (:YardNode, :ArrivalNode)]
    for (type1, type2) in possibleEdgeTypes
        for idx1 in nodeTypes[type1], idx2 in nodeTypes[type2]
            node1 = nodes[idx1]
            node2 = nodes[idx2]
            edgeWasAdded, cost = createEdge!(data, graph, node1, node2)
            if edgeWasAdded
                costs[node1.id, node2.id] = cost
            end
        end
    end
    return ScenarioGraph(graph, nodes, nodeTypes, costs, numScenarios)
end

"""
    Get nodes for one scenario for a given school
    Args:
        data::SchoolBusData    : the data
        schoolId::Int          : the id of the school
        currentNodeId          : id of node, incremented for each new node
        scenarioNum            : id of scenario
        nodeTypes              : the attributes of the ScenarioGraph that we are updating
    Returns:
        the nodes for that scenario
        the id of the current node (to be passed along to the next call)
"""
function getSchoolScenarioNodes!(data::SchoolBusData, schoolID::Int,
                                 currentNodeId::Int, scenarioNum::Int,
                                 nodeTypes::Dict{Symbol, Vector{Int}})
    schoolNodes = ScenarioNode[]
    scenario = data.scenarios[schoolID][scenarioNum]
    for routeID in scenario.routeIDs
        route = data.routes[schoolID][routeID]
        # create arrival nodes
        push!(schoolNodes, ArrivalNode(currentNodeId, schoolID, route,
                                       serviceTime(data, schoolID, route),
                                       scenario.id))
        push!(nodeTypes[:ArrivalNode], currentNodeId)
        currentNodeId += 1
    end
    push!(schoolNodes, DepartureNode(currentNodeId,schoolID,length(scenario.routeIDs),scenarioNum))
    push!(nodeTypes[:DepartureNode], currentNodeId)
    currentNodeId += 1
    return schoolNodes, currentNodeId
end

"""
    Get nodes for yards
"""
function getYardNodes!(data::SchoolBusData, nodeTypes::Dict{Symbol,Vector{Int}})
    yardNodes = ScenarioNode[]
    nodeId = 1
    for yard in data.yards
        push!(yardNodes, YardNode(nodeId, yard.id))
        push!(nodeTypes[:YardNode], nodeId)
        nodeId += 1
    end
    return yardNodes, nodeId
end

"""
    Decide whether a bus from one school can serve another school (time feasible)
    By convention, school 1 is the school from which the bus would depart in the morning, and
        the route belings to school 2
"""
function isFeasibleInTime(data::SchoolBusData, school1::Int, school2::Int,
                          route::Route, routeTime::Float64)
    return (data.schools[school1].starttime +
            traveltime(data, data.schools[school1], data.stops[school2][route.stops[1]]) +
            routeTime + data.schools[school2].dwelltime <= data.schools[school2].starttime)
end

"""
    Add edge between two nodes and compute cost of the edge
"""
function createEdge!(data::SchoolBusData, graph::DiGraph,
                     node1::ScenarioNode, node2::ScenarioNode)
    edgeWasAdded = false
    cost = nothing
    return edgeWasAdded, cost
end
function createEdge!(data::SchoolBusData, graph::DiGraph,
                     node1::DepartureNode, node2::ArrivalNode)
    edgeWasAdded = false
    if node1.school != node2.school
        # can only go to another school and route must be feasible
        if isFeasibleInTime(data, node1.school, node2.school,
                            node2.route, node2.serviceTime)
            edgeWasAdded = add_edge!(graph, node1.id, node2.id)
        end
    end
    return edgeWasAdded, 0.
end
function createEdge!(data::SchoolBusData, graph::DiGraph,
                     node1::DepartureNode, node2::YardNode)
    return add_edge!(graph, node1.id, node2.id), 0.
end
function createEdge!(data::SchoolBusData, graph::DiGraph,
                     node1::ArrivalNode, node2::DepartureNode)
    edgeWasAdded = false
    if node1.school == node2.school && node1.scenario == node2.scenario
        edgeWasAdded = add_edge!(graph, node1.id, node2.id)
    end
    return edgeWasAdded, 0.
end
function createEdge!(data::SchoolBusData, graph::DiGraph,
                     node1::YardNode, node2::ArrivalNode)
    return add_edge!(graph, node1.id, node2.id), 1.
end


"""
    Wrapper function replacing LightGraphs.out_edges since it was deprecated
    Returns a generator with the desired edges
"""
function edges_out(graph::DiGraph, node::Int)
    return (Edge(node, j) for j in outneighbors(graph, node))
end

"""
    Wrapper function replacing LightGraphs.in_edges since it was deprecated
    Returns a generator with the desired edges
"""
function edges_in(graph::DiGraph, node::Int)
    return (Edge(j, node) for j in inneighbors(graph, node))
end

"""
    Flow method for scenario selection
    Args:
        - the data
        - the scenario graph we've constructed
    Returns:
        - a vector of length the number of schools, containing the index of
                the scenario that is used for each school
"""
function selectScenario(data::SchoolBusData, sg::ScenarioGraph; args...)
    edgeCost(edge::Edge) = sg.costs[src(edge), dst(edge)]

    model = Model(solver = GurobiSolver(Threads=getthreads(), MIPGap=0.01; args...))

    @variable(model, useScenario[i=eachindex(data.schools), j=1:sg.numScenarios[i]], Bin)
    @variable(model, busFlow[edge=edges(sg.graph)] >= 0, Int)

    @constraint(model, capacityDeparture[i=sg.nodeTypes[:DepartureNode]],
                sum(busFlow[edge] for edge=edges_out(sg.graph, i)) <= sg.nodes[i].capacity)
    @constraint(model, capacityArrival[i=sg.nodeTypes[:ArrivalNode]],
                sum(busFlow[edge] for edge=edges_out(sg.graph, i)) ==
                useScenario[sg.nodes[i].school, sg.nodes[i].scenario])

    @constraint(model, oneScenario[i=eachindex(data.schools)],
                sum(useScenario[i,j] for j=1:sg.numScenarios[i]) == 1)

    @constraint(model, flowConservation[i=vertices(sg.graph)],
                sum(busFlow[edge] for edge=edges_in(sg.graph, i)) ==
                sum(busFlow[edge] for edge=edges_out(sg.graph, i)))

    @objective(model, Min, sum(busFlow[edge] * edgeCost(edge) for edge=edges(sg.graph)))

    status = solve(model)
    scenarioUsed = [indmax(getvalue(useScenario[i,j])
                           for j=1:sg.numScenarios[i]) for i=eachindex(sg.numScenarios)]
    return scenarioUsed
end

"""
    Represents node in FullRoutingGraph
    Mandatory attributes:
    - id::Int        : unique identifier
    - yardId::Int    : yard number
"""
abstract type FullRoutingNode end

"""
    In full routing flow graph, represents a bus with a certain capacity
"""
struct BusNode <: FullRoutingNode
    id::Int
    yardId::Int
    "Route associated with node"
    route::Route
    "School associated with node"
    school::Int
    "Service time of route"
    serviceTime::Float64
end

"""
    In full routing flow graph, represents a yard
"""
struct FullYardNode <: FullRoutingNode
    id::Int
    yardId::Int
end

"""
    Represents the situation after the scenario has been picked: one bus per route per school
    Similar to ScenarioGraph
"""
mutable struct FullRoutingGraph
    "The graph itself"
    graph::DiGraph
    "list of node objects"
    nodes::Vector{FullRoutingNode}
    "dictionary mapping pairs of nodes to costs"
    costs::Dict{Tuple{Int,Int},Float64}
end

"""
    Given routes object (such as that output by flow master problem), set up full routing graph
"""
function buildFullRoutingGraph(data::SchoolBusData, usedScenario::Vector{Int})
    nodes = FullRoutingNode[]
    costs = Dict{Tuple{Int,Int},Float64}()

    currentId = 1
    # yard nodes
    for yard in data.yards
        push!(nodes, FullYardNode(currentId, yard.id))
        currentId += 1
    end
    # school bus nodes
    for schoolID in eachindex(data.schools)
        scenario = data.scenarios[schoolID][usedScenario[schoolID]]
        for routeID in scenario.routeIDs
            route = data.routes[schoolID][routeID]
            for yard in data.yards
                push!(nodes, BusNode(currentId, yard.id, route, schoolID,
                                     serviceTime(data, schoolID, route)))
                currentId += 1
            end
        end
    end
    graph = DiGraph(length(nodes))
    # edges
    for node1 in nodes, node2 in nodes
        edgeWasAdded, cost = createEdge!(data, graph, node1, node2)
        if edgeWasAdded
            costs[node1.id, node2.id] = cost
        end
    end
    return FullRoutingGraph(graph, nodes, costs)
end

"""
    Method creates an edge between two nodes, with one function per type of node pair
"""
function createEdge!(data::SchoolBusData, graph::DiGraph,
                     node1::FullRoutingNode, node2::FullRoutingNode)
    return false, 0.
end
function createEdge!(data::SchoolBusData, graph::DiGraph,
                     node1::FullYardNode, node2::BusNode)
    edgeWasAdded, cost = false, 0.
    if node1.yardId == node2.yardId
        edgeWasAdded = add_edge!(graph, node1.id, node2.id)
        cost = traveltime(data, data.yards[node1.yardId],
                          data.stops[node2.school][node2.route.stops[1]])
    end
    return edgeWasAdded, cost
end
function createEdge!(data::SchoolBusData, graph::DiGraph,
                     node1::BusNode, node2::FullYardNode)
    edgeWasAdded, cost = false, 0.
    if node1.yardId == node2.yardId
        edgeWasAdded = add_edge!(graph, node1.id, node2.id)
        cost = traveltime(data, data.schools[node1.school], data.yards[node2.yardId])
    end
    return edgeWasAdded, cost
end
function createEdge!(data::SchoolBusData, graph::DiGraph,
                     node1::BusNode, node2::BusNode)
    edgeWasAdded, cost = false, 0.
    if node1.yardId == node2.yardId && node1.school != node2.school
        if isFeasibleInTime(data, node1.school,
                            node2.school, node2.route, node2.serviceTime)
            edgeWasAdded = add_edge!(graph, node1.id, node2.id)
            cost = traveltime(data, data.schools[node1.school],
                              data.stops[node2.school][node2.route.stops[1]])
        end
    end
    return edgeWasAdded, cost
end

"""
    Given a full routing graph, constructs a YardId => node dictionary
"""
function yardToNodeDict(frg::FullRoutingGraph)
    d = Dict{Int,Int}()
    for node in frg.nodes
        if typeof(node) == FullYardNode
            d[node.yardId] = node.id
        end
    end
    return d
end

"""
    Bus scheduling problem
"""
function solveFullRouting(data::SchoolBusData, frg::FullRoutingGraph; args...)
    model = Model(solver = GurobiSolver(Threads=getthreads(), MIPGap=0.01; args...))
    # variables - morning
    @variable(model, busFlow[edge=edges(frg.graph)], Bin)
    length([node for node in frg.nodes if typeof(node) == FullYardNode]) > 1 &&
        error("Too many yards")
    # variables - yard capacity
    @variable(model, yardCapacity[y=eachindex(frg.nodes);
                                  typeof(frg.nodes[y]) == FullYardNode] >= 0, Int)
    # a route can be served by at most one bus from a given yard - morning
    @constraint(model, oneBusPerRoute[nodeId=eachindex(frg.nodes);
                                      typeof(frg.nodes[nodeId]) == BusNode],
                sum(busFlow[edge] for edge = edges_in(frg.graph, nodeId)) == 1)
    # flow conservation constraints - morning
    @constraint(model, flowConservation[nodeId=vertices(frg.graph)],
                sum(busFlow[edge] for edge=edges_in(frg.graph, nodeId)) ==
                sum(busFlow[edge] for edge=edges_out(frg.graph, nodeId)))
    @constraint(model, flowBound[y=eachindex(frg.nodes);
                                 typeof(frg.nodes[y]) == FullYardNode],
                sum(busFlow[edge] for edge=edges_out(frg.graph, y)) <= yardCapacity[y])
    # minimize the total cost of buses (First Order = total number of bus)
    @objective(model, Min, sum(yardCapacity[y]
                               for (y,node)=enumerate(frg.nodes) if typeof(node) == FullYardNode))
    status = solve(model)
    flows = Dict(edge => getvalue(busFlow[edge]) for edge=edges(frg.graph))
    return interpretFlows!(data, frg, flows)
end

"""
    Given flows, get final buses
"""
function interpretFlows!(data::SchoolBusData, frg::FullRoutingGraph, flows::Dict)
    finalBuses = Bus[]
    currentBusId = 1
    dict = yardToNodeDict(frg)
    for yard in data.yards
        yardNode = dict[yard.id]
        yardIsEmpty = false
        # keep following bus routes until yard is empty
        while !yardIsEmpty
            schools, routes = followBusAlongRoute!(frg, flows, yardNode)
            if isempty(schools)
                yardIsEmpty = true
            else
                push!(finalBuses, Bus(currentBusId, yard.id, schools, routes))
                currentBusId += 1
            end
        end
    end
    return finalBuses
end

"""
    Extract a bus route from a flows object, removing flows as they are found
"""
function followBusAlongRoute!(frg::FullRoutingGraph, flows::Dict, yardNode::Int)
    schools, routes = Int[], Int[]
    if yardNode == -1 && length(flows) == 0
        return schools, routes
    end
    currentNode = yardNode
    backToYard = false
    while !backToYard
        for edge in edges_out(frg.graph, currentNode)
            if flows[edge] > 0.5
                if typeof(frg.nodes[dst(edge)]) == BusNode
                    push!(schools, frg.nodes[dst(edge)].school)
                    push!(routes, frg.nodes[dst(edge)].route.id)
                    currentNode = dst(edge)
                else
                    backToYard = true
                end
                flows[edge] = 0.
                break
            end
        end
        if isempty(schools) # couldn't find anything leading out of the yard
            backToYard = true
        end
    end
    return schools, routes
end

function routeBuses!(data::SchoolBusData)
    sg = buildScenarioGraph(data)
    data.usedScenario = selectScenario(data, sg, OutputFlag=0)
    frg = buildFullRoutingGraph(data, data.usedScenario)
    data.buses = solveFullRouting(data, frg, OutputFlag=0)
    data.withFinalBuses = true
    return data
end
