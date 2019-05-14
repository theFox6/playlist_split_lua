local time = {
	h=0,m=0,s=0,
	functions = {}
}
time.functions.__index = time

function time:new(o)
	return setmetatable(o or {}, self.functions)
end

function time.functions.__add(a,b)
	local s = a.s + b.s
	local m = math.floor(s/60) + a.m + b.m
	s = s % 60
	local h = math.floor(m/60) + a.h + b.h
	m = m % 60
	return time:new({h=h,m=m,s=s})
end

function time.functions.__sub(a,b)
	local h = a.h - b.h
	local m = a.m - b.m
	local s = a.s - b.s
	if s < 0 then
		m = m - 1
		s = s + 60
	end
	if m < 0 then
		h = h - 1
		m = m + 60
	end
	return time:new({h=h,m=m,s=s})
end

function time.functions.__concat(a,b)
	local str_a
	if time.is_time(a) then
		str_a = a:to_string()
	else
		str_a = a
	end
	if time.is_time(b) then
		return str_a .. b:to_string()
	else
		return str_a .. b
	end
end

function time.functions.__eq(a,b)
	return a.h == b.h and a.m == b.m and a.s == b.s
end

function time.functions.__lt(a,b)
	return a:total_seconds() < b:total_seconds()
end

function time.functions.__le(a,b)
	return a:total_seconds() <= b:total_seconds()
end

function time:to_string()
	return self.h..":"..self.m..":"..self.s
end

function time:total_seconds()
	return self.s + 60 * (self.m + self.h * 60)
end

function time.is_time(o)
	if type(o) == "table" and rawget(getmetatable(o), "__index")==time then
		return true
	end
	return false
end

function time.parse(str)
	local t = time:new()
	local numbers = str:split(":")
	if #numbers == 3 then
		t.s = tonumber(numbers[3])
		t.m = tonumber(numbers[2])
		t.h = tonumber(numbers[1])
	elseif #numbers == 2 then
		t.s = tonumber(numbers[2])
		t.m = tonumber(numbers[1])
	end
	return t
end

function time.test()
	local ten_seconds = time.parse("00:00:10")
	local ten_minutes = time.parse("10:00")
	local ten_minutes_b = time.parse("00:10:00")
	local ten_ten = time.parse("10:10")

	assert(time.is_time(ten_seconds), "parsed time is not a time object")
	assert(ten_minutes == ten_minutes_b, "ten minutes were parsed differently with or without hours")
	assert(ten_minutes > ten_seconds)
	assert(ten_seconds <= ten_minutes)
	assert(ten_seconds + ten_minutes == ten_ten, ten_minutes.." added to "..ten_seconds.." is not equal to"..ten_ten)
	assert(ten_seconds .. "s" == ten_seconds:to_string() .. "s")
end

time.test()

return time