###################################################
## pnas.jl
##     Run simulations for PNAS article
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

using SchoolBusRouting, JLD

RSRB = ["RSRB0$i" for i = 1:8];
CSCB = [@sprintf("CSCB%02d", i) for i = 1:16];
experiments = vcat(RSRB, CSCB);
maxtimes = [2700.0, 5400.0];

for experiment in experiments, maxtime in maxtimes 
    PATH = string(Pkg.dir("SchoolBusRouting"), "/data");
    data = JLD.load("$PATH/$experiment-$maxtime.jld", "data")

    data.params.max_time_on_bus = maxtime;
    λs = [1e2, 5e2, 5e3, 1e4, 5e4, 1e5, 5e5];
    if maxtime < 3000
        if experiment == "RSRB01"
            λs = [5e2, 5e3, 1e4, 5e4, 1e5, 2e5, 3e5, 4e5, 5e5, 1e4, 1e4, 1e4, 1e4, 1e4, 1e4, 1e4]
            params = [SchoolBusRouting.ScenarioParameters(maxRouteTimeLower=2000,
                                                          maxRouteTimeUpper=5000,
                                                          nGreedy=10, λ=λ,
                                                          nIterations=3) for λ in λs]
        else
            params = [SchoolBusRouting.ScenarioParameters(maxRouteTimeLower=2000,
                                                          maxRouteTimeUpper=5000,
                                                          nGreedy=20, λ=λ,
                                                          nIterations=80) for λ in λs]
        end
    else
        if experiment in ["RSRB01", "CSCB02"]
            λs = [5e2, 5e3, 1e4, 5e4, 1e5, 2e5, 3e5, 4e5, 5e5, 1e4, 1e4, 1e4, 1e4, 1e4, 1e4, 1e4]
            params = [SchoolBusRouting.ScenarioParameters(maxRouteTimeLower=2000,
                                                          maxRouteTimeUpper=7000,
                                                          nGreedy=1, λ=λ,
                                                          nIterations=1) for λ in λs]
        else
            params = [SchoolBusRouting.ScenarioParameters(maxRouteTimeLower=2000,
                                                          maxRouteTimeUpper=7000,
                                                          nGreedy=20, λ=λ,
                                                          nIterations=80) for λ in λs]
        end
    end
    bestBuses = Inf
    maxiter = experiment == "RSRB01" ? 10 : 3
    # random restarts
    for i = 1:maxiter
        srand(i)
        scenariolist = SchoolBusRouting.computescenarios(data, params);
        SchoolBusRouting.loadroutingscenarios!(data, scenariolist);
        SchoolBusRouting.routeBuses!(data, OutputFlag=0);
        if length(data.buses) < bestBuses
            bestBuses = length(data.buses)
            SchoolBusRouting.test(data)
    	end
    end
    println("$experiment\t$maxtime\t$bestBuses buses")
end
