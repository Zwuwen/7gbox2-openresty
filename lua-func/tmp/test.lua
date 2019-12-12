local mt = {}
mt.__add = function(t1,t2)
	local temp = {}
	for _,value in pairs(t1) do
		table.insert(temp,value)
	end
	for _,value in pairs(t2) do
		table.insert(temp,value)
	end
	return temp
end

local t1 = {1,2,3}
local t2 = {5}

setmetatable(t1,mt)

local t3 = t1 + t2
for _,value in pairs(t3) do
	print(value)
end

print("====================================")
mt.__call = function(mytable,...)
	for _,value in ipairs{...} do
		print(value)
	end
end
t = {}
setmetatable(t,mt)
t(1,2,3)

print("====================================")
mymetatable = {}
mytable = setmetatable({key1="value1"},{__newindex=mymetatable})
mytable.newkey = "new value2"
print(mymetatable.newkey)

	
