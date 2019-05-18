---
--Module handling times and durations.
--
--@module timetables
local timetables = {}

---
--A time.
--@type time
--@field #number h the hours
--@field #number m the minutes
--@field #number s the seconds
--@field #table functions the metatable of a time
local time = {
	h=0,m=0,s=0,
	functions = {}
}
---
-- the super reference
-- when indexing a time and the requested index is not found look inside time
time.functions.__index = time

---
-- The constructor for a new time object.
-- This will change the given object into a time or create a new one.
--
-- @function [parent=#time] new
-- @param #table o the object to be changed into a time
-- @return #time a new time object
function time:new(o)
	return setmetatable(o or {}, self.functions)
end

---
-- The addition method.
-- This will be called when times are added.
--
-- @function [parent=time#functions] __add
-- @param #time a the first time to be added
-- @param #time b the second time to be added
-- @return #time a new time resulting from the addition
function time.functions.__add(a,b)
	local s = a.s + b.s
	local m = math.floor(s/60) + a.m + b.m
	s = s % 60
	local h = math.floor(m/60) + a.h + b.h
	m = m % 60
	return time:new({h=h,m=m,s=s})
end

---
-- The subtraction method.
-- This will be called when times are subtracted.
--
-- @function [parent=time#functions] __sub
-- @param #time a the time to be subtracted from
-- @param #time b the time to be subtracted
-- @return #time a new time resulting from the subtraction
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

---
-- The concatenation method.
-- This will be called when times are concatenated (to strings).
--
-- @function [parent=time#functions] __concat
-- @param a the first value to be concatenated
-- @param b the second value to be concatenated
-- @return #string the string resulting from the concatenation
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

---
-- The equals method.
-- This will be called when times are checked for equality.
--
-- @function [parent=time#functions] __eq
-- @param #time a the first time to be compared
-- @param #time b the second time to be compared
-- @return #boolean whether the times are equal
function time.functions.__eq(a,b)
	return a.h == b.h and a.m == b.m and a.s == b.s
end

---
-- The less than method.
-- This will be called when times are compared for size.
--
-- @function [parent=time#functions] __lt
-- @param #time a the first time to be compared
-- @param #time b the second time to be compared
-- @return #boolean whether the first time is smaller than the second
function time.functions.__lt(a,b)
	return a:total_seconds() < b:total_seconds()
end

---
-- The less or equal than method.
-- This will be called when times are compared for size.
--
-- @function [parent=time#functions] __le
-- @param #time a the first time to be compared
-- @param #time b the second time to be compared
-- @return #boolean whether the first time is smaller than or the same as the second
function time.functions.__le(a,b)
	return a:total_seconds() <= b:total_seconds()
end

---
-- Get a string representation of the time.
-- This will put the time into a hh:mm:ss format.
--
-- @function [parent=#time] to_string
-- @param #time self the time to be formated
-- @return #string the string represenation of the time
function time:to_string()
	return self.h..":"..self.m..":"..self.s
end

---
-- Get the total number of seconds of a time.
-- This will add up the seconds, minutes and hours.
--
-- @function [parent=#time] total_seconds
-- @param #time self the time that the seconds should be counted of
-- @return #number the total number of seconds
function time:total_seconds()
	return self.s + 60 * (self.m + self.h * 60)
end

---
-- Check whether an object is a time.
-- This will look if the metatable is the one of a time.
--
-- @function [parent=#time]
-- @param #table o the object to be checked
-- @return #boolean whether it's a time
function time.is_time(o)
	return type(o) == "table" and rawget(getmetatable(o), "__index")==time
end

---
-- Parse a time from a string.
-- The string can be in hh:mm:ss format or in mm:ss format.
--
-- @function [parent=#timetables] parse
-- @param #string str the string to be parsed
-- @return #time the resulting time
function timetables.parse(str)
  local t = time:new()
  local h,m,s = str:match("^([%d.-]+):([%d.-]+):([%d.-]+)$")
  if h == nil then
    m,s = str:match("^([%d.-]+):([%d.-]+)$")
  else
    t.h = tonumber(h)
  end
  if m and s then
    t.m = tonumber(m)
    t.s = tonumber(s)
    return t
  end
end

---
-- Create a new time object.
-- Will change the given object into a time or create a new one.
--
-- @callof #timetables
-- @function [parent=#timetables] newTime
-- @param #table o the object to be changed into a time or nil
-- @return #time the new time object
function timetables.newTime(o)
  return time:new(o)
end

---
-- Check whether an object is a time.
-- Actually checks if the metatable is the one of a time.
--
-- @function [parent=#timetables] is_time
-- @param #table o the object to be checked
-- @return #boolean whether the object is a time
timetables.is_time = time.is_time

setmetatable(timetables,{__call=timetables.newTime})

---
-- Test the timetables module.
-- Assert the timetables module functions properly.
--
-- @function [parent=#timetables] test
function timetables.test()
	local ten_seconds = timetables.parse("00:00:10")
	local ten_minutes = timetables.parse("10:00")
	local ten_minutes_b = timetables.parse("00:10:00")
	local ten_ten = timetables.parse("10:10")

	assert(timetables.is_time(ten_seconds), "parsed time is not a time object")
	assert(ten_minutes == ten_minutes_b, "ten minutes were parsed differently with or without hours")
	assert(ten_minutes > ten_seconds)
	assert(ten_seconds <= ten_minutes)
	assert(ten_seconds + ten_minutes == ten_ten, ten_minutes.." added to "..ten_seconds.." is not equal to"..ten_ten)
	assert(ten_seconds .. "s" == ten_seconds:to_string() .. "s")
	assert(timetables() == timetables.parse("00:00:00"), "call of timetables is not equal zero time")
end

timetables.test()

return timetables