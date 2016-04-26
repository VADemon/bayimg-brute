-- this is not true OOP yet, just inheriting local values and stuff

local batchLogs = { files = { --[[ key = fileHandle ]] } }

-- atm, it will fkup if you define filePath in different ways
function batchLogs.line( filePath, text )
	if not batchLogs.files[ filePath ] then
		print("[DEBUG] File not open, ".. filePath)
		local fileHandle = io.open(filePath, "a+")
		fileHandle:setvbuf("full", 4096)	-- bytes, 4kB max buffer size, controlled by Lua
		
		batchLogs.files[ filePath ] = fileHandle
	end
	
	batchLogs.files[ filePath ]:write(text .. "\n")
end


function batchLogs.flushAll()
	for fileName, fileHandle in pairs( batchLogs.files ) do
		fileHandle:flush()
	end
end

function batchLogs.closeAll()
	for fileName, fileHandle in pairs( batchLogs.files ) do
		fileHandle:close()
	end
end

return batchLogs