using SchoolBusRouting, JLD, DataFrames, CSV

# experiment parameters
experiments = vcat(["RSRB0$i" for i = 1:8], ["CSCB0$i" for i = 1:8]);
maxtimes = [2700.0, 5400.0];
conditions = ["one", "many", "Chen", "combined", "LBH"]
maxiter = 1

# output arrays
exp_id = Int[]; benchmark = AbstractString[]; exp_name = AbstractString[];
max_riding_time = Float64[]; nbuses = Int[]; iter = Int[];

counter = 0
for maxtime in (maxtimes), experiment in (experiments)
	# load data from ASCII files
	PATH = "$(Pkg.dir("SchoolBusRouting"))/data/input"
	data = SchoolBusRouting.loadSyntheticBenchmark("$PATH/$experiment/Schools.txt",
									  "$PATH/$experiment/Stops.txt")
	data.params.max_time_on_bus = maxtime
	println("***********************************************")
	println("$experiment - $maxtime")
	for condition in conditions, i=1:maxiter
		counter += 1
		scenariolist = []
		params = []
		if condition in ["many", "combined"]
			# many scenarios
			λs = [1e2, 5e2, 5e3, 1e4, 5e4, 1e5, 5e5, 1e6];
			nGreedy = 20; nIterations = 80;
			if experiment == "RSRB02" && maxtime < 4000
				λs = [1e2, 5e2, 1e3, 2e3, 5e3, 7e3, 1e4, 5e4, 1e5, 5e5, 1e6, 5e6, 1e7, 2e7];
				nGreedy = 40; nIterations = 150;
			end
			params = [SchoolBusRouting.ScenarioParameters(maxRouteTimeLower=maxtime-2000,
											 maxRouteTimeUpper=maxtime+2000,
											 nGreedy=nGreedy, λ=λ,
											 nIterations=nIterations) for λ in λs]
			srand(i)
			scenariolist = SchoolBusRouting.computescenarios(data, params; OutputFlag=0,
			                                    MIPGap=ifelse(maxtime < 4000, 1e-4, 0.05),
			                                    TimeLimit=ifelse(maxtime < 4000, 90, 30));
		end
		if condition == "one"
			params = [SchoolBusRouting.ScenarioParameters(maxRouteTimeLower=maxtime-2000,
											 maxRouteTimeUpper=maxtime+2000,
											 nGreedy=ifelse(maxtime < 4000, 30, 20), λ=λ,
											 nIterations=ifelse(maxtime < 4000, 120, 100)
											 ) for λ in [1e8]]
			srand(i)
			scenariolist = SchoolBusRouting.computescenarios(data, params; OutputFlag=0,
			                                    MIPGap=ifelse(maxtime < 4000, 1e-4, 0.05),
			                                    TimeLimit=ifelse(maxtime < 4000, 90, 30));
		end
		if condition in ["Chen", "combined"]
			mapping = Dict(stop.originalId => (stop.schoolId,
			                                   stop.id) for stop in vcat(data.stops...))
			routestops = [Vector{Int}[] for school in data.schools]
			servicetimes = [Float64[] for school in data.schools]
			found = false
			for line in readlines("$(Pkg.dir("SchoolBusRouting"))/data/routes/$(experiment[1:4])$(Int(round(maxtime)))/SBRP_$experiment.txt")
				if ((line != "NODE_COORD_SECTION" && !found) || 
					(split(line, ":")[1] == "DIMENSION" && found))
					found = false
					continue
				elseif !found
					found = true
					continue
				end
				elements = split(line, "\t")
				stoplist = [mapping[parse(Int64, a)][2] for a in elements[11:end]]
				servicetime = parse(Float64, elements[4])
				destination = parse(Int64, elements[8]) - 200000
				@assert all([mapping[parse(Int64,a)][1] for a in elements[11:end]] .== destination)
				if length(stoplist) > 0
					push!(routestops[destination], stoplist)
					push!(servicetimes[destination], servicetime)
				end
			end
			routes = [[SchoolBusRouting.Route(j, stops) for (j, stops) in enumerate(routestops[i])] for i = eachindex(routestops)];
			scenariolist = vcat(scenariolist,
			                    [(SchoolBusRouting.Scenario(i, length(params)+1, collect(eachindex(routes[i]))),
			                     routes[i]) for i=eachindex(routes)])
		end
		if condition == "LBH"
			scenarios, routes, usedscenario, buses = SchoolBusRouting.lbh(data)
			SchoolBusRouting.loadsolution!(data, scenarios, routes, usedscenario, buses)
		else
			SchoolBusRouting.loadroutingscenarios!(data, scenariolist);
			SchoolBusRouting.routeBuses!(data, OutputFlag=0, TimeLimit=3600);
		end
		SchoolBusRouting.test(data)
		println("$counter - $condition: $(length(data.buses)) buses")
		CSV.write("$(Pkg.dir("SchoolBusRouting"))/output/tableS1/solution-$counter.csv", SchoolBusRouting.output(data))
		push!(nbuses, length(data.buses))
		push!(exp_id, counter)
		push!(benchmark, experiment)
		push!(max_riding_time, maxtime)
		push!(exp_name, condition)
		push!(iter, i)
		JLD.save("$(Pkg.dir("SchoolBusRouting"))/output/tableS1/solution-$counter.jld", "data", data)
	end
end
df = DataFrame()
df[:exp_id] = exp_id; df[:benchmark] = benchmark; df[:exp_name] = exp_name;
df[:max_riding_time] = max_riding_time; df[:buses] = nbuses; df[:iter] = iter;
CSV.write("$(Pkg.dir("SchoolBusRouting"))/output/pnas-tableS1.csv", df)
