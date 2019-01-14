###################################################
## output.jl
##      Output data and solutions to ASCII readable format
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

"""
	Convert number of seconds since midnight to DateTime format
"""
function totime(x)
	newx = round(x, 3)
	hours = div(newx, 3600)
	minutes = div(newx % 3600, 60)
	seconds = floor(newx % 60)
	thousands = Int(round(1000 * (newx - floor(newx))))
	return Dates.Time(hours, minutes, seconds, thousands)
end

"""
    Output full routing solution to dataframe
"""
function output(data::SchoolBusData)
    !data.withFinalBuses && error("Final routes not computed")
    bus_id = Int[]
    start_loc = Int[]
	end_loc = Int[]
    start_time = Dates.Time[]
	end_time = Dates.Time[]
	action = String[]
	for (j, bus) in enumerate(data.buses)
		for (i, school) in enumerate(bus.schools)
			route = bus.routes[i]
			src = [data.stops[school][data.routes[school][route].stops[end]].uniqueId + 100000]
			dst = [data.schools[school].id + 200000]
			currenttime = data.schools[school].starttime - data.schools[school].dwelltime
			dst_t = [totime(currenttime)]
			currenttime -= traveltime(data,
			                          data.stops[school][data.routes[school][route].stops[end]],
			                          data.schools[school])
			src_t = [totime(currenttime)]
			act = ["travel"]
			for k in length(data.routes[school][route].stops):-1:2
				stop = data.routes[school][route].stops[k]
				# add waiting time at stop
				unshift!(act, "pickup")
				unshift!(dst_t, src_t[1])
				unshift!(dst, src[1])
				unshift!(src, src[1])
				currenttime -= stopTime(data, data.stops[school][stop])
				unshift!(src_t, totime(currenttime))
				# add travel time from previous stop
				unshift!(act, "travel")
				unshift!(dst_t, src_t[1])
				unshift!(dst, src[1])
				prev = data.routes[school][route].stops[k-1]
				unshift!(src, data.stops[school][prev].uniqueId + 100000)
				currenttime -= traveltime(data, data.stops[school][prev], data.stops[school][stop])
				unshift!(src_t, totime(currenttime))
			end
			stop = data.routes[school][route].stops[1]
			unshift!(act, "pickup")
			unshift!(dst_t, src_t[1])
			unshift!(dst, src[1])
			unshift!(src, src[1])
			currenttime -= stopTime(data, data.stops[school][stop])
			unshift!(src_t, totime(currenttime))
			if i == 1
				unshift!(act, "deadhead")
				unshift!(dst_t, src_t[1])
				unshift!(dst, src[1])
				unshift!(src, 900000 + bus.yard)
				currenttime -= traveltime(data, data.yards[bus.yard], data.stops[school][stop])
				unshift!(src_t, totime(currenttime))
			else
				unshift!(act, "deadhead")
				unshift!(dst_t, src_t[1])
				unshift!(dst, src[1])
				unshift!(src, 200000 + data.schools[bus.schools[i-1]].id)
				currenttime -= traveltime(data, data.schools[bus.schools[i-1]],
				                          data.stops[school][stop])
				unshift!(src_t, totime(currenttime))
				unshift!(act, "wait")
				unshift!(dst_t, src_t[1])
				unshift!(dst, src[1])
				unshift!(src, src[1])
				currenttime = data.schools[bus.schools[i-1]].starttime
				unshift!(src_t, totime(currenttime))
				unshift!(act, "dropoff")
				unshift!(dst_t, src_t[1])
				unshift!(dst, src[1])
				unshift!(src, src[1])
				currenttime -= data.schools[bus.schools[i-1]].dwelltime
				unshift!(src_t, totime(currenttime))
			end
			# add this school to the itinerary
			append!(start_loc, src)
			append!(end_loc, dst)
			append!(start_time, src_t)
			append!(end_time, dst_t)
			append!(bus_id, j * ones(Int, length(src)))
			append!(action, act)
		end
		# add final school and return to the yard
		append!(action, ["dropoff", "deadhead"])
		append!(bus_id, [j, j])
		push!(start_loc, end_loc[end])
		push!(start_time, end_time[end])
		push!(end_loc, end_loc[end])
		currenttime = data.schools[bus.schools[end]].starttime
		push!(end_time, totime(currenttime))
		push!(start_loc, end_loc[end])
		push!(start_time, end_time[end])
		push!(end_loc, bus.yard + 900000)
		currenttime += traveltime(data, data.schools[bus.schools[end]], data.yards[bus.yard])
		push!(end_time, totime(currenttime))
	end
	df = DataFrame()
	df[:bus_id] = bus_id
	df[:start_loc] = start_loc
	df[:end_loc] = end_loc
	df[:action] = action
	df[:start_time] = start_time
	df[:end_time] = end_time
	return df
end
