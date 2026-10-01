-- Profile share codes: turns a profile into a text code players can copy and paste, and back.
-- Pure logic: no WoW API calls, so it can be unit tested outside the game.
--
-- Codes contain only letters, digits and a few separators, so chat, Discord and WoW's edit
-- boxes (which treat "|" specially) don't mangle them. Decoding never runs any code: the text
-- is parsed by hand and checked field by field.

local _, ns = ...

local Share = {}
ns.Share = Share

local PREFIX = "BagSections1:"
local MAX_DEPTH = 6
local MAX_STRING = 200

-- Strings: letters and digits as they are, everything else as %XX.
local function EscapeString(s)
	return (s:gsub("[^%w]", function(c) return ("%%%02X"):format(c:byte()) end))
end

local function UnescapeString(s)
	return (s:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function Serialize(value, out)
	local kind = type(value)
	if kind == "string" then
		local escaped = EscapeString(value)
		table.insert(out, "s" .. #escaped .. "_" .. escaped)
	elseif kind == "number" then
		table.insert(out, "n" .. ("%.4f"):format(value):gsub("%.?0+$", "") .. "_")
	elseif kind == "boolean" then
		table.insert(out, value and "T" or "F")
	elseif kind == "table" then
		table.insert(out, "{")
		-- Arrays in order, then other keys sorted, so the same profile gives the same code.
		local keys = {}
		for key in pairs(value) do
			if type(key) == "string" or (type(key) == "number" and (key < 1 or key > #value or key % 1 ~= 0)) then
				table.insert(keys, key)
			end
		end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, item in ipairs(value) do
			Serialize(item, out)
		end
		table.insert(out, ";")
		for _, key in ipairs(keys) do
			Serialize(key, out)
			Serialize(value[key], out)
		end
		table.insert(out, "}")
	end
end

local function Checksum(s)
	local sum = 0
	for i = 1, #s do
		sum = (sum * 31 + s:byte(i)) % 16777213
	end
	return ("%06X"):format(sum)
end

function Share.Encode(name, profile)
	local out = {}
	Serialize({ name = name, profile = profile }, out)
	local body = table.concat(out)
	return PREFIX .. body .. ":" .. Checksum(body)
end

-- Parser over the body; returns value, next position, or nil on any malformed input.
local Parse

local function ParseString(s, pos)
	local len, rest = s:match("^s(%d+)_()", pos)
	len = tonumber(len)
	if not len or len > MAX_STRING * 3 then
		return nil
	end
	local escaped = s:sub(rest, rest + len - 1)
	if #escaped ~= len then
		return nil
	end
	return UnescapeString(escaped), rest + len
end

Parse = function(s, pos, depth)
	local c = s:sub(pos, pos)
	if c == "s" then
		return ParseString(s, pos)
	elseif c == "n" then
		local num, rest = s:match("^n(%-?[%d%.]+)_()", pos)
		num = tonumber(num)
		if not num then return nil end
		return num, rest
	elseif c == "T" then
		return true, pos + 1
	elseif c == "F" then
		return false, pos + 1
	elseif c == "{" then
		if depth >= MAX_DEPTH then return nil end
		local result = {}
		pos = pos + 1
		while s:sub(pos, pos) ~= ";" do
			local value
			value, pos = Parse(s, pos, depth + 1)
			if value == nil then return nil end
			table.insert(result, value)
		end
		pos = pos + 1
		while s:sub(pos, pos) ~= "}" do
			local key, value
			key, pos = Parse(s, pos, depth + 1)
			if key == nil or type(key) == "table" then return nil end
			value, pos = Parse(s, pos, depth + 1)
			if value == nil then return nil end
			result[key] = value
		end
		return result, pos + 1
	end
	return nil
end

local function ValidColor(c)
	if c == nil then
		return true
	end
	if type(c) ~= "table" then
		return false
	end
	for _, k in ipairs({ "r", "g", "b" }) do
		if type(c[k]) ~= "number" or c[k] < 0 or c[k] > 1 then
			return false
		end
	end
	return true
end

local function ValidName(name)
	return type(name) == "string" and name ~= "" and #name <= MAX_STRING
end

-- Checks a decoded profile has exactly the shape a profile should, and copies only the known
-- fields, so a hand-edited code can't put anything unexpected into saved data.
local function CleanProfile(profile)
	if type(profile) ~= "table" or type(profile.sections) ~= "table" then
		return nil
	end
	local clean = { sections = {} }
	for _, section in ipairs(profile.sections) do
		if type(section) ~= "table" or not ValidName(section.name) or not ValidColor(section.color) then
			return nil
		end
		if section.auto ~= nil and section.auto ~= "quest" then
			return nil
		end
		local color = section.color and { r = section.color.r, g = section.color.g, b = section.color.b } or nil
		table.insert(clean.sections, {
			name = section.name,
			below = section.below == true,
			collapsed = section.collapsed == true,
			auto = section.auto,
			color = color,
		})
	end
	if profile.rows ~= nil then
		if type(profile.rows) ~= "table" then
			return nil
		end
		clean.rows = {}
		for _, row in ipairs(profile.rows) do
			if type(row) ~= "table" then
				return nil
			end
			local cleanRow = {}
			for _, entry in ipairs(row) do
				if type(entry) ~= "table" then
					return nil
				end
				if entry.rest == true then
					table.insert(cleanRow, { rest = true })
				elseif ValidName(entry.name) then
					table.insert(cleanRow, { name = entry.name })
				else
					return nil
				end
			end
			table.insert(clean.rows, cleanRow)
		end
	end
	return clean
end

-- Returns name, profile; or nil and an error key ("format" or "damaged").
function Share.Decode(code)
	if type(code) ~= "string" then
		return nil, "format"
	end
	code = code:gsub("%s", "")
	if code:sub(1, #PREFIX) ~= PREFIX then
		return nil, "format"
	end
	local body, checksum = code:sub(#PREFIX + 1):match("^(.*):(%x%x%x%x%x%x)$")
	if not body then
		return nil, "format"
	end
	if Checksum(body) ~= checksum:upper() then
		return nil, "damaged"
	end
	local ok, data, nextPos = pcall(Parse, body, 1, 0)
	if not ok or type(data) ~= "table" or nextPos ~= #body + 1 then
		return nil, "damaged"
	end
	local profile = CleanProfile(data.profile)
	if not profile or not ValidName(data.name) then
		return nil, "damaged"
	end
	return data.name, profile
end
