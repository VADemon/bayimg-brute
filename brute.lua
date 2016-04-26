-- http://www.asciitable.com/index/asciifull.gif

local dictChars = "97-112"

function rangeToList( dictChars ) -- numeric interval to list with integer values
	dictChars = string.gsub(dictChars, " ", "")
	local rangeList, i = {}, 1
	-- ToDO add a function to easily add it in a for i=1,y loop
	for word in string.gmatch(dictChars, "[^,]%d+") do
		rangeList[i] = tonumber(word)
		
			if rangeList[i] > 0 then
				i = i+1 --proceed
			else --it's an array of IDs 204-207
				local prev, curr = rangeList[i-1], rangeList[i]*-1 --faster than math.abs()
				local step = 1
				if prev > curr then --if the first number is bigger than the second one (e.g. "470-464")
					step = -1 --we need to count downwards
				end
				i = i-1 --trust me. We don't wanna to have the same ID twice
				for x = prev, curr, step do
					rangeList[i] = x
					i = i+1
				end
			end
	end
		
	return rangeList
end

bruteforceChars = rangeToList(dictChars)
print("Current bruteforce dictionary: ")
for k,v in pairs( bruteforceChars ) do io.write(k .. "=" .. string.char(v) .. "\t") end print()

function raiseCharID( id )
	for c = 1, #bruteforceChars do
		if bruteforceChars[ c ] == id then
			local carry = false	-- carry means that the next followed char must be raised as well
			
			if c ~= #bruteforceChars then
				return bruteforceChars[ c+1 ], carry
			else
				carry = true
				return bruteforceChars[ 1 ], carry
			end
		end
	end
end

function raiseChar( char )
	local id, carry = raiseCharID(string.byte( char ))
	return string.char(id), carry
end

function raiseString( str )
	repeat
		local carry = false
		local currentCharPosition = #str
		
		repeat
			local begin, targetChar, ending = string.sub(str, 1, currentCharPosition - 1), string.sub(str, currentCharPosition, currentCharPosition), string.sub(str, currentCharPosition + 1)
			targetChar, carry = raiseChar( targetChar )
			str = begin .. targetChar .. ending
			
			if currentCharPosition == 1 then
				if carry then
					str = string.char(bruteforceChars[ 1 ]) .. str
					
					carry = false
				end
				
			else
				currentCharPosition = currentCharPosition - 1
			end
		until carry == false
		
	until passedFilter(str) == true	-- repeat the whole process until the filter returns true
	
	return str
end

function genNextString( lastString, startLength, maxLength )
	if not lastString or #lastString == 0 then
		return string.char(bruteforceChars[ 1 ]):rep( startLength )
	end

	--
	
	local nextString = raiseString( lastString )
	
	if #nextString <= maxLength then
		return nextString
	else
		return ""
	end
end

-- generates data for parallelisation of bruteforcing, serving kind of as a Master Server
-- splits the given range into smaller portions that can be handed out to smaller worker units
-- retuns data that can be used to generate a portion of the given range

-- startString = start incrementing from here
-- finalString = last string of the range
-- startLength = if startString is not provided then generate a starting string of this length
-- maxLength = a string cannot be longer than this
-- count = how many strings will a portion contain? (can be equal or less than count)
function genStringRange(startString, finalString, startLength, maxLength, count)
	if (finalString == nil or finalString == "") and (maxLength == nil or maxLength == 0) then
		print("[ERROR] FinalString or MaxLength must be defined!")
		return false
	end
	if (maxLength == nil or maxLength == 0) then
		maxLength = #finalString
	end
	if finalString == nil then
		finalString = ""
	end
	if count == nil or count == 0 then
		print("[INFO] Count is not defined! Setting default to 100")
		count = 100
	end
	
	local blacklist = loadBlacklist("blacklist-bayimg.txt")
	
	local portion_finalString, portion_startLength, portion_maxLength = nil, startLength or 1, nil
	local portions = {
		-- [id] = portion Data
		--		portionData = {[1] = startString, finalString, maxLength, count}
	}
	
	local working = true
	local portionCounter = 1
	local lastStr = startString or ""
	
	while working do
		portions[ portionCounter ] = {}
				
		lastStr = genNextString(lastStr, startLength, maxLength)
		portions[ portionCounter ][1] = lastStr	-- first string
		--print(lastStr)
		for n = 2, count do
			local penultimate = lastStr	-- to be able to define the last string in the list when lastStr==""
			lastStr = genNextString(lastStr, startLength, maxLength)
			--print(lastStr)
			if n == count or lastStr == "" or lastStr == finalString then
				portions[ portionCounter ][2] = penultimate	-- last string
				portions[ portionCounter ][3] = #penultimate	-- maxLength
				portions[ portionCounter ][4] = n	-- how many strings in that portion
				
				if lastStr == "" or lastStr == finalString then
					working = false	-- whole range is finished, exit
				end
				
				break	-- exit current portion's loop
			end
		end
		
		portionCounter = portionCounter + 1	-- increate portion counter
	end
	
	return portions
end

-- refer to genStringRange() for explanation of arguments
-- filePath = will contain portionData
-- separator = separation character. if set to NIL then by default ; (semicolon)
function writePortions(filePath, separator, portions)
	if type(portions) ~= "table" then
		print("[ERROR] You must pass a portions table as the 3rd argument!")
		return false
	end
	
	local file = assert(io.open(filePath, "w+"))
	local sep = separator or ""
	if #sep == 0 then sep = ";" end
	
	if #portions == 0 then
		print("[ERROR] Portions table is empty!")
	else
		print("[INFO] Portions table has ".. #portions .." portions.")
	end
	
	for i = 1, #portions do
		--[[print(i, "1=",portions[1])
		print(i, "2=",portions[2])
		print(i, "3=",portions[3])
		print(i, "4=",portions[4])]]
		file:write("portion" .. sep .. i .. sep .. portions[i][1] .. sep .. portions[i][2] .. sep .. portions[i][3] .. sep .. portions[i][4] .. "\n")
	end
	file:close()
	print("Finished writing portions to file ".. filePath)
	
	return true
end

-- filter for bruteforce sequences
-- returns TRUE if the string is a valid target to bruteforce
function passedFilter(str)
	if blacklist and blacklist[str] then
		return false	-- is blacklisted
	end
	
	if str:sub(2,2) == "a" or str:sub(6,6) == "a" or str:sub(7,7) == "a" then
		print("Didnt pass filter: ".. str)
		return false
	else
		return true
	end
	
	return false
end

print("Full Syntax: doBruteforce( 'fromString', 'toString', minStringLength, maxStringLength )")
print("Either fromString-toString or minLength, maxLength are optional\n")
function doBruteforce(startString, finalString, startLength, maxLength)
	local nextString
	
	if type(startString) == "string" then
		nextString = startString
	else
		print("fromString is not specified! The range will start from an empty string.\n")
		nextString = ""
		os.execute("sleep 3")
	end
	
	if type(finalString) == "string" then
		print("Range set from '".. nextString .."' to '".. finalString .."'\n")
	else
		print("toString is not specified, the range end is now only limited by maxStringLength!\n")
		finalString = nil
		os.execute("sleep 3")
	end
	
	if type(startLength) ~= "number" then
		if type(startString) ~= "string" then
			print("minStringLength is not specified! The bruteforce will start from a single character string\n")
		end
		startLength = 1
	end
	
	if type(maxLength) ~= "number" then
		if finalString then
			maxLength = #finalString
		else
			print("ERROR: You did not specify maxStringLength nor toString!")
			print("Quitting!")
			os.exit(1)
		end
	end
	
	local blacklist = loadBlacklist()
	local batchList = {}
	local batchSize = 100	-- Amount of parallel CURL instances, e.g. check 24 URLs at once -> 24 cURL instances
	batchLogs = dofile("logging.lua")
	
	repeat
		nextString = genNextString( nextString, startLength, maxLength )
		
		if nextString ~= "" and blacklist[ nextString ] ~= true then
			-- run curl
			local isValid = passedFilter(nextString)
			if isValid then
				batchList[ #batchList + 1] = nextString
				
				if #batchList >= batchSize then
					curlGrab(batchList)
					batchList = {}
				end
				--print("valid: ".. nextString)
			end
			
		end
		
		if type(nextString) == "nil" or (finalString and nextString and nextString == finalString) then
			
			break
		end
		
		--print(nextString, nextString and #nextString)
	until (nextString == nil) or (fileExists("STOP") == true)
	
	if #batchList ~= 0 then
		curlGrab(batchList)
		batchList = {}
	end
	
	
	if fileExists("STOP") == true then
		print("STOP file detected! Quitting...")
	elseif(finalString and nextString and nextString == finalString) then
		print("Finished! Reached the finalString: ".. finalString .." (last string processed)")
	else
		print("Looks like we've hit the bruteforce target. Finished! Quitting...")
	end
	
	batchLogs.closeAll()
	os.exit(0)
	return true
end

function curlGrab( usernameList )
	local command = ""
	local usernamesString = ""
	local lastUsername = "-undefined-"
	
	for i = 1, #usernameList do
		local username = usernameList[i]
		command = command .. "curl -I -L --max-time 3.5 --silent --write-out 'user".. username .." %{http_code}\\n' http://home.online.no/~".. usernameList[i] .. "/ & \n"
		usernamesString = usernamesString .. username .. "  "
		
		if i == #usernameList then
			lastUsername = username
		end
	end
	command = command .. "wait"
	
	print("Next up:")
	print(usernamesString)
	local pipe = io.popen(command)
	local serverResponse = pipe:read("*a")
	
	os.execute("sleep 0.1")
	pipe:close()
	
	
	local responseStats = {}	-- collect the statistics instead of printing everything to console
	
	for	username, status_code in serverResponse:gmatch("user(.-) (%d+)") do
		status_code = tonumber(status_code)
		
		responseStats = tableIncrementValue( responseStats, status_code, 1 )
		
		if status_code == 200 then
		
			print("~"..username, status_code, "OK")
			batchLogs.line("200.txt", "~".. username)
			
		elseif status_code == 404 then
		
			--os.execute("echo ~".. username .." >> 404.txt")
			
		elseif status_code == 0 then
		
			batchLogs.line("000.txt", "~".. username)
			
		else
			print("Detected an unexpected response code!")
			os.execute("echo ~".. username .." >> ".. status_code ..".txt")
		end
	end
	
	io.write("Received status codes: ")
	for k, v in pairs( responseStats ) do
		io.write("[".. k .."]: ".. v ..", ")
	end
	io.write("\n")
	
	print("Last checked username: ~".. lastUsername .."\n")
end

function loadBlacklist(path)
	local blacklist = {}
	local filePath = path or "blacklisted-strings.txt"
	local file
	local entryCount = 0
	
	if fileExists( filePath ) then
		file = io.open(filePath, "r")
	else
		print("Blacklist file ".. filePath .." does not exist, skipping...")
		return blacklist
	end
	
	
	for line in file:lines() do
		if blacklist[ line ] ~= true then
			blacklist[ line ] = true
			entryCount = entryCount + 1
		end
	end
	
	file:close()
	print("Blacklist loaded, ".. entryCount .." entries!")
	os.execute("sleep 2")
	return blacklist
end

-- table, key, amount
function tableIncrementValue( tabl, key, amount )
	local value = tabl[ key ] or 0
	local amount = amount or 1
	
	if value then
		tabl[ key ] = value + amount
		return tabl
	end
end

function fileExists( path )
	local fileHandle = io.open(path, "r")
	
	if fileHandle then
		fileHandle:close()
		return true
	end
	
	return false
end