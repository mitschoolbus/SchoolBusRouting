# Using the school bus routing problem visualization tool

```julia
julia> using SchoolBusRouting, JLD

julia> data = JLD.load("$(Pkg.dir("SchoolBusRouting"))/output/tableS1/solution-1.jld", "data")

julia> SchoolBusRouting.visualize(data)
```

The last command above opens an interactive visualizer. You can:
- zoom in by pressing the Z key
- zoom out by pressing the X key
- enlarge the nodes by pressing the A key
- make the nodes smaller by pressing the S key

Schools are represented as pentagons of different colors, and bus stops are represented as red squares. Click on a school to only show the bus stops for that school. Click again on the same school to show all bus stops again.

Press R to enter "route mode" and display the routes. In "route mode", if you click on a school, it will show all routes for that school (connecting relevant stops with black lines). If you click on a route, it will show the entire itinerary for the bus that serves that route.
 
