###################################################
## viz.jl
##      Visualizes Student/Schools/Stops data (without network)
## Authors: Arthur Delarue, Sébastien Martin, 2019
###################################################

struct RouteSFML
    stopids::Vector{Int}
    arcshapes::Vector{SFML.Line}
    clickpoints::Vector{Vector2f}
    bus::Int
end

PALETTE = Plots.get_color_palette(:auto, Plots.plot_color(:white), 17)
SFMLPALETTE = repeat([SFML.Color(round.(Int,[c.r,c.g,c.b]*255)...) for c in PALETTE], outer=20)
function visualize(data::SchoolBusData)
    nodeRadius = 100.

    # Defines the window, an event listener, and view
    window_w, window_h = 1200,1200
    window = SFML.RenderWindow("School Bus Problem", window_w, window_h)
    SFML.set_vsync_enabled(window, true)
    event = SFML.Event()

    # positions
    schoolpositions = [(school.position.x, school.position.y) for school in data.schools]
    yardpositions = [(yard.position.x, yard.position.y) for yard in data.yards]
    tmp = Dict(stop.uniqueId => (stop.position.x, stop.position.y) for stop in vcat(data.stops...))
    stoppositions = [tmp[i] for i=1:maximum(keys(tmp))]
    allpositions = vcat(schoolpositions,yardpositions,stoppositions)

    #Set the window size
    minX, maxX = extrema(x for (x,y) in allpositions)
    minY, maxY = extrema(y for (x,y) in allpositions)

    # Do the Y-axis transformation
    minY, maxY = -maxY, -minY
    networkLength = max(maxX-minX, maxY-minY)
    viewWidth = max(maxX-minX, (maxY-minY)*window_w/window_h)
    viewHeigth = max(maxY-minY, (maxX-minX)*window_h/window_w)
    view = SFML.View(SFML.Vector2f((minX+maxX)/2,(minY+maxY)/2), SFML.Vector2f(viewWidth, viewHeigth))
    zoomLevel = 1.0

    # init visualizer
    hideStops = false
    routemode = false
    selectedSchool = 0
    selectedbus = 0
    schoolShapes = [SFML.CircleShape() for i in eachindex(data.schools)]
    for s in schoolShapes
        SFML.set_pointcount(s,5)
    end
    
    stopShapes = [SFML.CircleShape() for i in eachindex(stoppositions)]
    for s in stopShapes
        SFML.set_pointcount(s,4)
        SFML.set_fillcolor(s, SFML.Color(255,0,0))
    end

    function drawroute(sfmlroute)
        for cornerstopid in sfmlroute.stopids
            SFML.draw(window, stopShapes[cornerstopid])
        end
        for routeedge in sfmlroute.arcshapes
            SFML.draw(window, routeedge)
        end
    end
    
    if data.withFinalBuses
        routetobus = Dict{Tuple{Int,Int},Int}() # (schoolid, routeid)->busid
        for bus in data.buses
            for (schoolid,routeid) in zip(bus.schools,bus.routes)
                routetobus[schoolid,routeid] = bus.id
            end
        end
        sfmlroutes = RouteSFML[]
        schoolroutes = Vector{Int}[Int[] for school in data.schools]
        busroutes = Vector{Int}[Int[] for bus in data.buses]
        for school in data.schools
            chosenscenario = data.scenarios[school.id][data.usedScenario[school.id]]
            routes = data.routes[school.id][chosenscenario.routeIDs]
            
            for route in routes
                routesegments = SFML.Line[]
                cornerstops = Int[]
                clickpoints = SFML.Vector2f[]

                busstopids = route.stops

                originstop = data.stops[school.id][busstopids[1]]
                originpos = (originstop.position.x, originstop.position.y)
                push!(cornerstops, originstop.uniqueId)

                for i in 2:length(busstopids)
                    deststop = data.stops[school.id][busstopids[i]]
                    destpos = (deststop.position.x, deststop.position.y)
                    l = SFML.Line(SFML.Vector2f(originpos[1], -originpos[2]), SFML.Vector2f(destpos[1], -destpos[2]))
                    SFML.set_thickness(l, nodeRadius/1.5)
                    SFML.set_fillcolor(l, SFML.Color(100,100,100))
                    push!(routesegments,l)
                    push!(cornerstops, deststop.uniqueId)

                    dist = sqrt((originpos[1]-destpos[1])^2 + (originpos[2]-destpos[2])^2)
                    xs = linspace(originpos[1], destpos[1], 2+floor(Int, dist/50.))
                    ys = linspace(originpos[2], destpos[2], 2+floor(Int, dist/50.))
                    for (x,y) in zip(xs,ys)
                        push!(clickpoints, SFML.Vector2f(x,y))
                    end
                    originpos = destpos
                end
                # add last move to school
                destpos = schoolpositions[school.id]
                l = SFML.Line(SFML.Vector2f(originpos[1], -originpos[2]), SFML.Vector2f(destpos[1], -destpos[2]))
                SFML.set_thickness(l, nodeRadius/1.5)
                SFML.set_fillcolor(l, SFML.Color(100,100,100))
                dist = sqrt((originpos[1]-destpos[1])^2 + (originpos[2]-destpos[2])^2)
                xs = linspace(originpos[1], destpos[1], 2+floor(Int, dist/50.))
                ys = linspace(originpos[2], destpos[2], 2+floor(Int, dist/50.))
                for (x,y) in zip(xs,ys)
                    push!(clickpoints, SFML.Vector2f(x,y))
                end
                push!(routesegments,l)

                push!(sfmlroutes, RouteSFML(cornerstops,routesegments, clickpoints, routetobus[school.id,route.id]))
                push!(schoolroutes[school.id], length(sfmlroutes))
                push!(busroutes[routetobus[school.id,route.id]], length(sfmlroutes))
            end
        end
        connectingsegments = Vector{SFML.Line}[SFML.Line[] for bus in data.buses]
        for bus in data.buses
            if length(bus.schools) > 1
                for i in 2:length(bus.schools)
                    schoolpos = schoolpositions[bus.schools[i-1]]
                    route = data.routes[bus.schools[i]][bus.routes[i]]
                    firststoppos = (data.stops[bus.schools[i]][route.stops[1]].position.x,
                                    data.stops[bus.schools[i]][route.stops[1]].position.y)
                    l = SFML.Line(SFML.Vector2f(schoolpos[1], -schoolpos[2]), SFML.Vector2f(firststoppos[1], -firststoppos[2]))
                    SFML.set_thickness(l, nodeRadius/1.5)
                    SFML.set_fillcolor(l, SFML.Color(100,100,100))
                    push!(connectingsegments[bus.id], l)
                end
            end
        end
    end

    schoolstops = Int[] # school stops to be drawn
    walkingshapes = SFML.Line[]


    function selectschool(schoolId)
        selectedSchool = schoolId
        schoolstops = Int[]
        for stop in data.stops[schoolId]
            cornerstopid = stop.uniqueId
            stopposition = stoppositions[cornerstopid]
            push!(schoolstops, cornerstopid)
        end
    end

    function redraw()
        schoolRadius = selectedSchool > 0 ? nodeRadius*1.5 : nodeRadius*4
        stopRadius = nodeRadius*2
        for (i,s) in enumerate(schoolShapes)
            SFML.set_radius(s, schoolRadius)
            SFML.set_fillcolor(s, SFMLPALETTE[i])

            SFML.set_position(s, SFML.Vector2f(schoolpositions[i][1] - schoolRadius,-schoolpositions[i][2] - schoolRadius))
        end
        for (i,s) in enumerate(stopShapes)
            SFML.set_radius(s, stopRadius)
            SFML.set_position(s, SFML.Vector2f(stoppositions[i][1] - stopRadius,-stoppositions[i][2] - stopRadius))
        end
        if selectedSchool > 0
            for (i,s) in enumerate(schoolShapes)
                SFML.set_fillcolor(s, SFML.Color(255,255,255))
            end
            s = schoolShapes[selectedSchool]
#             SFML.set_fillcolor(s, SFML.Color(0,255,0))
            SFML.set_radius(s, 4*schoolRadius)
            SFML.set_fillcolor(s, SFMLPALETTE[selectedSchool])
                        
            SFML.set_position(s, SFML.Vector2f(schoolpositions[selectedSchool][1] - 4*schoolRadius,-schoolpositions[selectedSchool][2] - 4*schoolRadius))
        end
        if data.withFinalBuses
            for route in sfmlroutes, (arcid, arc) in enumerate(route.arcshapes)
                SFML.set_thickness(arc, nodeRadius/1.5)
            end
            for busconnectors in connectingsegments, line in busconnectors
                SFML.set_thickness(line, nodeRadius/1.5)
            end
        end
    end
    redraw()
    
    # Constructing school position tree
    schoolPos = Array{Float64}(2,length(data.schools))
    for (i,school) in enumerate(data.schools)
       schoolPos[1,i] = schoolpositions[i][1]
       schoolPos[2,i] = schoolpositions[i][2]
    end
    schoolTree = NearestNeighbors.KDTree(schoolPos)

    if data.withFinalBuses
    # Constructing route position tree
        positions = Array{Float64}(2,sum(length(route.clickpoints) for route in sfmlroutes))
        clickpoint2route = Int[]
        i = 1
        for (routeid,route) in enumerate(sfmlroutes), clickpoint in route.clickpoints
            positions[1,i] = clickpoint[1]
            positions[2,i] = clickpoint[2]
            push!(clickpoint2route, routeid)
            i+=1
        end
        routeTree = NearestNeighbors.KDTree(positions)
    end

    clock = SFML.Clock()
    # gc_enable(false)
    while SFML.isopen(window)
        frameTime = Float64(SFML.as_seconds(SFML.restart(clock)))
        while SFML.pollevent(window, event)
            if SFML.get_type(event) == SFML.EventType.CLOSED
                SFML.close(window)
            end
            if SFML.get_type(event) == SFML.EventType.RESIZED
                size = SFML.get_size(event)
                window_w, window_h = size.width, size.height
                viewWidth = max(maxX-minX, (maxY-minY)*window_w/window_h)
                viewHeigth = max(maxY-minY, (maxX-minX)*window_h/window_w)
                SFML.set_size(view, SFML.Vector2f(viewWidth, viewHeigth))
                SFML.zoom(view, zoomLevel)
            end
            if SFML.get_type(event) == SFML.EventType.KEY_PRESSED
                k = SFML.get_key(event).key_code
                if k == SFML.KeyCode.ESCAPE || k == SFML.KeyCode.Q
                    SFML.close(window)
                    break;
                elseif k == SFML.KeyCode.A
                    nodeRadius *= 1.3
                    redraw()
                elseif k == SFML.KeyCode.S
                    nodeRadius /= 1.3
                    redraw()
                elseif k == SFML.KeyCode.G
                    if selectedSchool == 0
                        hideStops = !hideStops
                    end
                elseif k == SFML.KeyCode.R
                    if data.withFinalBuses
                        routemode = !routemode
                    end
                end
            end
            if SFML.get_type(event) == SFML.EventType.MOUSE_BUTTON_PRESSED && SFML.get_mousebutton(event).button == SFML.MouseButton.LEFT
                x,y = SFML.get_mousebutton(event).x, SFML.get_mousebutton(event).y
                coord = SFML.pixel2coords(window,SFML.Vector2i(x,y))
                if routemode
                    if selectedbus == 0
                        clickpoint = NearestNeighbors.knn(routeTree, [Float64(coord.x),-Float64(coord.y)],1)[1][1]
                        routeid = clickpoint2route[clickpoint]
                        selectedbus = sfmlroutes[routeid].bus
                        selectedSchool = 0
                    else
                        selectedbus = 0
                    end
                else
                    schoolId = NearestNeighbors.knn(schoolTree,[Float64(coord.x),-Float64(coord.y)],1)[1][1]
                    if schoolId == selectedSchool
                        selectedSchool = 0
                    else
                        selectschool(schoolId)
                    end
                end
                redraw()
            end
        end
        if SFML.is_key_pressed(SFML.KeyCode.LEFT)
            SFML.move(view, SFML.Vector2f(-networkLength/2*frameTime*zoomLevel,0.))
        end
        if SFML.is_key_pressed(SFML.KeyCode.RIGHT)
            SFML.move(view, SFML.Vector2f(networkLength/2*frameTime*zoomLevel,0.))
        end
        if SFML.is_key_pressed(SFML.KeyCode.UP)
            SFML.move(view, SFML.Vector2f(0.,-networkLength/2*frameTime*zoomLevel))
        end
        if SFML.is_key_pressed(SFML.KeyCode.DOWN)
            SFML.move(view, SFML.Vector2f(0.,networkLength/2*frameTime*zoomLevel))
        end
        if SFML.is_key_pressed(SFML.KeyCode.Z)
            SFML.zoom(view, 0.6^frameTime)
            zoomLevel = SFML.get_size(view).x/viewWidth
        end
        if SFML.is_key_pressed(SFML.KeyCode.X)
            SFML.zoom(view, 1/(0.6^frameTime))
            zoomLevel = SFML.get_size(view).x/viewWidth
        end
        SFML.set_view(window,view)
        SFML.clear(window, SFML.Color(255,255,255))
        
        # Draw students
        if selectedSchool != 0
            if routemode
                for sfmlrouteid in schoolroutes[selectedSchool]
                    drawroute(sfmlroutes[sfmlrouteid])
                end
            else
                for walkingline in walkingshapes
                    SFML.draw(window, walkingline)
                end
                # only draw corner stops that are used
                for s in stopShapes[schoolstops]
                    SFML.draw(window, s)
                end
            end
        else
            if routemode
                if selectedbus > 0
                    for sfmlrouteid in busroutes[selectedbus]
                        drawroute(sfmlroutes[sfmlrouteid])
                    end
                    for line in connectingsegments[selectedbus]
                        SFML.draw(window, line)
                    end
                else
                    for route in sfmlroutes
                        drawroute(route)
                    end
                end
            else
                # Draw stops
                if !hideStops
                    for s in stopShapes
                        SFML.draw(window, s)
                    end
                end
            end
        end
        # Draw schools
        for s in schoolShapes
            SFML.draw(window, s)
        end
        SFML.display(window)
    end
end