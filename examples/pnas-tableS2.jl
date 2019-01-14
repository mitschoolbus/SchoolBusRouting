using SchoolBusRouting, JLD, DataFrames, CSV

# experiment parameters
conditions = ["one", "many", "LBH"]
maxiter = 1
maxtime = 3600.
fractions = [0.05, 0.1, 0.15, 0.2, 0.25]
schools = [50, 100, 150, 200]

# output arrays
exp_id = Int[]; exp_name = AbstractString[]; nbuses = Int[]; iter = Int[];

counter = 0
for i = 1:maxiter, f in fractions, s in schools, condition in conditions
	srand(i)
	counter += 1
	data = SchoolBusRouting.syntheticproblem(nschools=s,
	                            nyards=1,
	                            districtsize = 30000.,
	                            dwelltime = 10.*60.,
	                            studentsperschool = 100, 
	                            schoolrange=(3000., 8000.),
	                            studentspread=200.,
	                            studentclustering=0.66,
	                            maxwalking=1610*0.5,
	                            d2dfraction=f)
	println("***********************")
	@show data
	data.params.max_time_on_bus = maxtime
	data.params.velocity = 35/3.6 # 35 kph
	scenariolist = []
	params = []
	if condition == "many"
		# many scenarios
		λs = [1e2, 5e2, 5e3, 1e4, 5e4, 1e5];
		params = [SchoolBusRouting.ScenarioParameters(maxRouteTimeLower=maxtime-2000,
										 maxRouteTimeUpper=maxtime+2000,
										 nGreedy=10, λ=λ,
										 nIterations=10) for λ in λs]
		srand(i)
		scenariolist = SchoolBusRouting.computescenarios(data, params, OutputFlag=0, MIPGap=1e-4, TimeLimit=90);
	elseif condition == "one"
		params = [SchoolBusRouting.ScenarioParameters(maxRouteTimeLower=maxtime-2000,
										 maxRouteTimeUpper=maxtime+2000,
										 nGreedy=20, λ=λ,
										 nIterations=50) for λ in [1e8]]
		srand(i)
		scenariolist = SchoolBusRouting.computescenarios(data, params, OutputFlag=0, MIPGap=1e-4, TimeLimit=90);
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
	CSV.write("$(Pkg.dir("SchoolBusRouting"))/output/tableS2/solution-$counter.csv", SchoolBusRouting.output(data))
	push!(nbuses, length(data.buses))
	push!(exp_id, counter)
	push!(exp_name, condition)
	push!(iter, i)
	JLD.save("$(Pkg.dir("SchoolBusRouting"))/output/tableS2/solution-$counter.jld", "data", data)
end
df = DataFrame()
df[:exp_id] = exp_id; df[:exp_name] = exp_name; df[:buses] = nbuses; df[:iter] = iter;
CSV.write("$(Pkg.dir("SchoolBusRouting"))/output/pnas-tableS2.csv", df)
