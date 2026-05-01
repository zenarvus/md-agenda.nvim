local config = require("md-agenda.config")

--functions and variables that are used in multiple files
local common = {}

local vim = vim

-----------VARS--------------
common.oneDay = 24*60*60 --one day in seconds

------------GET MAP ITEM COUNT--------------
common.getMapItemCount = function(map)
	local count = 0
	for _, _ in pairs(map) do
		count = count + 1
	end
	return count
end

common.splitFoldmarkerString = function()
	local result = {}
	for item in string.gmatch(config.config.foldmarker, "([^,]+)") do
		table.insert(result, item)
	end
	return result
end

common.isTodoItem = function(itemType)
	if itemType == "TODO" then
		return true
	else
		for customTodoType, _ in pairs(config.config.customTodoTypes) do
			if itemType == customTodoType then
				return true
			end
		end
	end

	return false
end


local function isDirectory(path)
	local stat = vim.loop.fs_stat(path)
	return stat and stat.type == 'directory'
end

common.listFiles = function(filesPath)
	local files = {}
	for _, filePath in ipairs(filesPath) do
		filePath = vim.fn.expand(filePath)

		if isDirectory(filePath) then
			local fileList =
				vim.fn.systemlist("rg --files --glob '!.*' --glob '*.md' --glob '*.mdx' " .. filePath)
			for _, oneFile in ipairs(fileList) do
				table.insert(files, oneFile)
			end
		else
			table.insert(files, filePath)
		end
	end

	return files
end

--Gets the given unixTime's weekday and month, then based on the start point, counts the occurrence of this weekday from the start or the end until the given unixTime (Example: given date is in Monday and its the third monday in January from the start).
local function getWeekdayOccurenceCountInMonthUntilGivenDate(startPoint, unixTime)
--\{{{
	local timeTable = os.date("*t", unixTime)
	local occurrenceCount = 0

	--Start from the start
	if startPoint == 1 then
		local firstDayOfMonth = os.time({year = timeTable.year, month = timeTable.month, day=1})

		--Find the first same weekday of the same month
		local occurrence = firstDayOfMonth
		while os.date("*t", occurrence).wday ~= timeTable.wday  do

			occurrence = occurrence + common.oneDay
		end

		--After the first same weekday found, increase it by one week until it has the same day with given unixTime
		while occurrence <= unixTime do
			occurrenceCount = occurrenceCount + 1

			occurrence = occurrence + common.oneDay * 7
		end

	--Start from the end
	elseif startPoint == -1 then
		--To get the last day of this month, get the next month's first day, then subtract one day, finally, convert the new result to the table.
		local lastDayOfMonth = os.time(os.date("*t", os.time({year = timeTable.year, month = timeTable.month+1, day=1}) - common.oneDay))

		--Find the last same weekday of the same month
		local occurrence = lastDayOfMonth
		while os.date("*t", occurrence).wday ~= timeTable.wday do

			occurrence = occurrence - common.oneDay
		end

		--After the last same weekday found, decrease it by one week until it has the same day with given unixTime
		while unixTime <= occurrence do
			occurrenceCount = occurrenceCount + 1

			occurrence = occurrence - common.oneDay * 7
		end
	end

	return occurrenceCount
--\}}}
end

common.parseTaskTime = function(timeString)
--\{{{
	--time string's format: 2025-12-30 18:05 +1d (the last one is the repeat interval and is optional)
	local taskTimeMap = {}

	local year,month,day=timeString:match("([0-9]+)-([0-9]+)-([0-9]+)")
	local hour,minute=timeString:match("([0-9]+):([0-9]+)")
	if (not hour) and (not minute) then
		hour = "0"
		minute = "0"
	end

	local taskTimeTable = {
		year = tonumber(year),
		month = tonumber(month),
		day = tonumber(day),
		hour = tonumber(hour),
		min = tonumber(minute),
		sec = 0,  -- seconds can be set to 0
		isdst = false  -- daylight saving time flag
	}
	local taskUnixTime = os.time(taskTimeTable)
	taskTimeMap["unixTime"]=taskUnixTime

	local currentUnixTime = os.time()
	local currentTimeTable = os.date("*t", currentUnixTime)

	--make it day start
	currentTimeTable.hour, currentTimeTable.min, currentTimeTable.sec = 0,0,0

	--repeat indicator's format: ++12d, +3w, .+1m etc.
	local repeatType, repeatNum, repeatInterval = timeString:match(" ([%.%+]+)([0-9]+)([a-z])")

	if repeatType and repeatNum and repeatInterval then

		if repeatType ~= "+" and repeatType ~= "++" and repeatType ~= ".+" then
			print("invalid repeat type. You can only use '+', '++' and '.+'")
			return
		end

		taskTimeMap["repeatType"] = repeatType

		if repeatInterval ~= "d" and repeatInterval ~= "w" and repeatInterval ~= "m" and repeatInterval ~= "y" and
		repeatInterval ~= "x" and repeatInterval ~= "z" then
			print("invalid repeat interval. You can only use d(day), w(week), m(month), y(year), x and z")
			return
		end

		local num = tonumber(repeatNum)

		if num <= 0 then
			print("repeat indicator number cannot be zero or less than zero")
			return taskTimeMap
		end

		local timeTableToBeUsed = {}
		if repeatType == "+" or repeatType == "++" then
			--Consider task's date day start
			timeTableToBeUsed = taskTimeTable
			--timeTableToBeUsed.hour, timeTableToBeUsed.min = 0,0

		elseif repeatType == ".+" then
			--Consider today's date
			timeTableToBeUsed = currentTimeTable
		end

		----------------

		--day
		if repeatInterval=="d" then
			timeTableToBeUsed.day=timeTableToBeUsed.day+num
			taskTimeMap["nextUnixTime"] = os.time(timeTableToBeUsed)

		--week
		elseif repeatInterval=="w" then
			timeTableToBeUsed.day=timeTableToBeUsed.day+7*num
			taskTimeMap["nextUnixTime"] = os.time(timeTableToBeUsed)

		--month
		elseif repeatInterval=="m" then
			timeTableToBeUsed.month = timeTableToBeUsed.month + num
			taskTimeMap["nextUnixTime"] = os.time(timeTableToBeUsed)

		--year
		elseif repeatInterval=="y" then
			timeTableToBeUsed.year = timeTableToBeUsed.year + num
			taskTimeMap["nextUnixTime"] = os.time(timeTableToBeUsed)

		--x or z
		elseif repeatInterval=="x" or repeatInterval=="z" then
			local taskDateWithDetails = os.date("*t", taskUnixTime)
			local taskWeekday = taskDateWithDetails.wday
			local taskMonth = taskDateWithDetails.month
			local taskYear = taskDateWithDetails.year

			if repeatInterval=="x" then
				--Weekday's occurrence count in the month from the month's start to the taskUnixTime
				local occurrenceCount = getWeekdayOccurenceCountInMonthUntilGivenDate(1,taskUnixTime)

				taskTimeMap["nextUnixTime"] = os.time({year=taskYear+num, month=taskMonth, day=1})
				--Do a loop until the nexUnixTime's weekday and its occurrenceCount is equal to task's
				while os.date("*t", taskTimeMap["nextUnixTime"]).wday ~= taskWeekday and
				occurrenceCount ~= getWeekdayOccurenceCountInMonthUntilGivenDate(1, taskTimeMap["nextUnixTime"]) do

					taskTimeMap["nextUnixTime"] = taskTimeMap["nextUnixTime"] + common.oneDay
				end

			elseif repeatInterval=="z" then
				--Weekday's occurrence count in the month from the month's end to the taskUnixTime
				local occurrenceCount = getWeekdayOccurenceCountInMonthUntilGivenDate(-1,taskUnixTime)

				taskTimeMap["nextUnixTime"] = os.time({year=taskYear+num, month=taskMonth, day=1})
				--Do a loop until the nexUnixTime's weekday and its occurrenceCount is equal to task's
				while os.date("*t", taskTimeMap["nextUnixTime"]).wday ~= taskWeekday and
				occurrenceCount ~= getWeekdayOccurenceCountInMonthUntilGivenDate(-1, taskTimeMap["nextUnixTime"]) do

					taskTimeMap["nextUnixTime"] = taskTimeMap["nextUnixTime"] + common.oneDay
				end
			end

		end

		-----------------

		--if the repeat type is "++" and the next unix time is in the past, increase it until it shows a future time.
		if repeatType=="++" and taskTimeMap["nextUnixTime"] < currentUnixTime then
				local taskDateWithDetails = os.date("*t", taskUnixTime)
				--start the nextUnixTime from today.
				taskTimeMap["nextUnixTime"] = currentUnixTime
				while true do
					if currentUnixTime < taskTimeMap["nextUnixTime"] then
						if repeatInterval=="d" then
							break

						elseif repeatInterval=="w" then
							if taskDateWithDetails.wday == os.date("*t", taskTimeMap["nextUnixTime"]).wday then
								break
							end

						elseif repeatInterval=="m" then
							if taskDateWithDetails.day == os.date("*t", taskTimeMap["nextUnixTime"]).day then
								break
							end

						elseif repeatInterval=="y" then
							if taskDateWithDetails.month == os.date("*t", taskTimeMap["nextUnixTime"]).month and
							taskDateWithDetails.day == os.date("*t", taskTimeMap["nextUnixTime"]).day then
								break
							end

						elseif repeatInterval=="x" or repeatInterval=="z" then
							if taskDateWithDetails.year < os.date("*t", taskTimeMap["nextUnixTime"]).year and
							taskDateWithDetails.wday == os.date("*t", taskTimeMap["nextUnixTime"]).wday and
							taskDateWithDetails.month == os.date("*t", taskTimeMap["nextUnixTime"]).month then
								if repeatInterval=="x" and
								getWeekdayOccurenceCountInMonthUntilGivenDate(1, taskTimeMap["nextUnixTime"]) == getWeekdayOccurenceCountInMonthUntilGivenDate(1,taskUnixTime) then
									break
								elseif repeatInterval=="z" and
								getWeekdayOccurenceCountInMonthUntilGivenDate(-1, taskTimeMap["nextUnixTime"]) == getWeekdayOccurenceCountInMonthUntilGivenDate(-1,taskUnixTime) then
									break
								end
							end
						end

						local nextUnixTime = taskTimeMap["nextUnixTime"] + common.oneDay
						taskTimeMap["nextUnixTime"] = nextUnixTime
					end
				end
		end

		taskTimeMap["nextTimeStr"] = os.date("%Y-%m-%d %H:%M", taskTimeMap["nextUnixTime"]) .." "..repeatType..repeatNum..repeatInterval
	end

	return taskTimeMap
--\}}}
end

--Checks if the given date is in the range of the given task time string
--wantedDateStr's format: 2000-12-30
--if returned value is false, it means that date is a free time
common.IsDateInRangeOfGivenRepeatingTimeStr = function(repeatingTimeStr, wantedDateStr)
	local ryear,rmonth,rday=repeatingTimeStr:match("([0-9]+)-([0-9]+)-([0-9]+)")

	local repeatingTimeTable = {
		year = tonumber(ryear),
		month = tonumber(rmonth),
		day = tonumber(rday),
		isdst = false  -- daylight saving time flag
	}
	local repeatingTimeUnix = os.time(repeatingTimeTable)

	local wyear,wmonth,wday=wantedDateStr:match("([0-9]+)-([0-9]+)-([0-9]+)")
	local wantedDateTable = {
		year = tonumber(wyear),
		month = tonumber(wmonth),
		day = tonumber(wday),
		isdst = false
	}
	local wantedDateUnix = os.time(wantedDateTable)

	local repeatType, repeatNumStr, repeatInterval = repeatingTimeStr:match(" ([%.%+]+)([0-9]+)([a-z])")
	if repeatType and repeatNumStr and repeatInterval then

		local repeatNum = tonumber(repeatNumStr)

		-------------------

		if repeatType ~= "+" and repeatType ~= "++" and repeatType ~= ".+" then
			print("invalid repeat type. You can only use '+', '++' and '.+'")
			return false
		end
		if repeatInterval ~= "d" and repeatInterval ~= "w" and repeatInterval ~= "m" and repeatInterval ~= "y" and
		repeatInterval ~= "x" and repeatInterval ~= "z" then
			print("invalid repeat interval. You can only use d(day), w(week), m(month), y(year), x and z.")
			return false
		end

		local num = tonumber(repeatNum)

		if num <= 0 then
			print("repeat indicator number cannot be zero or less than zero")
			return false
		end

		--------------------

		if repeatInterval == "y" then
			if repeatingTimeTable.month == wantedDateTable.month and
			repeatingTimeTable.day == wantedDateTable.day then
				return true

			else return false end

		elseif repeatInterval == "m" then
			if repeatingTimeTable.day == wantedDateTable.day then
				return true

			else return false end

		elseif repeatInterval == "w" then
			if os.date("*t",repeatingTimeUnix).wday == os.date("*t",wantedDateUnix) then
				return true

			else return false end

		elseif repeatInterval == "d" then
			--days since epoch
			local repeatingTimeDSE = math.floor(repeatingTimeUnix / common.oneDay)
			local wantedDateDSE = math.floor(wantedDateUnix / common.oneDay)

			--this formula means that we can eventually arrive to wantedDate from repeatingTime if we add or subtract repeatNum 
			if (wantedDateDSE - repeatingTimeDSE) % repeatNum == 0 then
				return true

			else return false end

		--------
		elseif repeatInterval == "x" then
			if os.date("*t", wantedDateUnix).wday == os.date("*t", repeatingTimeUnix).wday and
			wantedDateTable.month == repeatingTimeTable.month then
				if getWeekdayOccurenceCountInMonthUntilGivenDate(1, wantedDateUnix) == getWeekdayOccurenceCountInMonthUntilGivenDate(1, repeatingTimeUnix) then
					return true
				end
			end
			return false

		elseif repeatInterval == "z" then
			if os.date("*t", wantedDateUnix).wday == os.date("*t", repeatingTimeUnix).wday and
			wantedDateTable.month == repeatingTimeTable.month then
				if getWeekdayOccurenceCountInMonthUntilGivenDate(-1, wantedDateUnix) == getWeekdayOccurenceCountInMonthUntilGivenDate(-1, repeatingTimeUnix) then
					return true
				end
			end
			return false
		end

	else
		print("Given date is not a repeating task")
		return false
	end
end

-------------GET TASK PROPERTIES-------------
-- its not just for current buffer but all files. So we use content lines array instead
common.getTaskProperties = function(ContentLinesArr, taskLineNum, withLineNum)
	--{key={propertyLineNum, value}, ...} or {key=value, ...}
	local properities = {}

	local propertyLineNum = taskLineNum + 1

	local currentLine = 0
	for _,line in ipairs(ContentLinesArr) do
		currentLine = currentLine + 1

		if currentLine < propertyLineNum then
			goto continue
		end

		local propertyPattern = "^ *- (.+): `(.*)`"

		local key,value = line:match(propertyPattern)
		if key and value then
			--if value points to a lua script
			local luaScriptPath = value:match("%$%((.*)%)")
			if luaScriptPath then
				--make the value the returned lua script value
				if withLineNum then
					properities[key]={propertyLineNum, loadfile(luaScriptPath)()}

				else properities[key]=loadfile(luaScriptPath)() end
			else
				if withLineNum then
					properities[key]={propertyLineNum, value}

				else properities[key]=value end
			end

			propertyLineNum=propertyLineNum+1
		else
		  break
		end

		::continue::
	end

	return properities
end

--add a new property to the task or update the existing one
common.addPropertyToItem = function(fileLines, itemLineNum, key, value)

	local taskProperties = common.getTaskProperties(fileLines, itemLineNum, true)

	-- If it exists, update
	if taskProperties[key] then
		local propertyLineNum = taskProperties[key][1]
		fileLines[propertyLineNum] = string.format("- %s: `%s`", key, value)

	-- If it does not exist, create
	else
		local newProperty = string.format("- %s: `%s`", key, value)
		table.insert(fileLines, itemLineNum + 1, newProperty)
	end

	return fileLines
end

--New function that uses given filepath instead of the current buffer.
common.addItemToLogbook = function(fileLines, itemLineNum, logStr)
	local lineNum = itemLineNum+1

	local logbookExists = false
	local logbookStart=0

	--determine if the task has a logbook
	while true do
		local lineContent = fileLines[lineNum]

		--if reached to another header or end of the file, stop
		if #fileLines < lineNum or lineContent:match(" *#+") then
			break
		end

		if lineContent:match(".*<details logbook>") then
			logbookStart = lineNum
			logbookExists = true
			break
		end

		lineNum=lineNum+1
	end

	-- Get user's foldmarker setting or use default
	local foldmarker_start, foldmarker_end
	local userFoldMethod = vim.o.foldmethod
	if userFoldMethod == "marker" and vim.o.foldmarker ~= "" then
		local markers = vim.split(vim.o.foldmarker, ",")
		foldmarker_start = markers[1] or "{{{"
		foldmarker_end = markers[2] or "}}}"
	end

	if logbookExists then
		--there must be a line space between <details logbook> html tag and markdown. So we put new markdown log to two line under the details tag
		table.insert(fileLines, logbookStart + 2, "  " .. logStr)

		--if logbook does not found, create one and insert the logStr
	else
		--insert below properties
		local properties = common.getTaskProperties(fileLines, itemLineNum, true)
		local propertyCount = common.getMapItemCount(properties)

		local newLines = {}

		-- Only add fold markers if user uses marker folding method
		if userFoldMethod == "marker" then
			table.insert(newLines, "<details logbook><!--" .. foldmarker_start .. "-->")
		else
			table.insert(newLines, "<details logbook>")
		end

		table.insert(newLines, "")
		table.insert(newLines, logStr)

		-- Only add fold markers if user uses marker folding method
		if userFoldMethod == "marker" then
			table.insert(newLines, "<!--" .. foldmarker_end .. "--></details>")
		else
			table.insert(newLines, "</details>")
		end

		for i, newLine in ipairs(newLines) do
			table.insert(fileLines, itemLineNum + propertyCount + i, newLine)
		end
	end

	return fileLines
end

---------------GET LOGBOOK ENTRIES---------------
common.getLogbookEntries = function(ContentLinesArr, taskLineNum)
	--{date={status, time, progress}, ...}
	local entries = {}

	local logbookStartPassed = false

	local lineNumber = 0
	for _,line in ipairs(ContentLinesArr) do
		lineNumber = lineNumber+1

		--skip task headline
		if lineNumber < taskLineNum+1 then goto continue end

		if line:match(".*<details logbook>") then
			logbookStartPassed = true
		end

		if logbookStartPassed then
			--example logbook line: - DONE: `2022-12-30 18:80` `(6/10)`
			local status, text = line:match(" *- ([A-Z]+): (.*)")

			if status and text then
				local log = {}

				table.insert(log, status)

				local time = text:match("`([0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+)`")
				if not time then
					goto continue
				end

				table.insert(log, time)

				local progressIndicator = text:match("`(%([0-9]+/[0-9]+%))`")
				if progressIndicator then
					table.insert(log, progressIndicator)
				end

				local date = time:match("([0-9]+-[0-9]+-[0-9]+)")
				entries[date] = log
			end
		end

		--stop when arrived to another header or logbook's end
		if line:match("^#+ .*") or line:match(".*</details>") then
			break
		end
		::continue::
	end

	return entries
end

----------------LIST ALL AGENDA ITEMS----------------

--detailLevel: minimal or anything
common.getAgendaItems = function(detailLevel)
	--[[{
		{
			metadata={filePath, lineNumber}
			agendaItem={type, text, fullLine}
			properties={key=value} --if not minimal
			logbookItems={{item type, time, progress}, ...} --if not minimal
		},
		{...},
		...
	}--]]
	local agendaItems = {}

	for _,agendaFilePath in ipairs(common.listFiles(config.config.agendaFiles)) do
		local file_content = vim.fn.readfile(agendaFilePath)
		if file_content then
			local lineNumber = 0
			for _,line in ipairs(file_content) do
				lineNumber = lineNumber+1

				local taskType,title = line:match("^#+ (.+): (.*)")
				if taskType and title then

					local agendaItem = {}

					agendaItem.metadata ={agendaFilePath, lineNumber}

					agendaItem.agendaItem ={taskType, title, line}

					if detailLevel ~= "minimal" then
						agendaItem.properties = common.getTaskProperties(file_content, lineNumber)

						--Try to get the logbook entries only if the agenda item has a repeat indicator.
						if (agendaItem.properties["Scheduled"] and agendaItem.properties["Scheduled"]:match(" [%.%+]+[0-9]+[a-z]")) or
						(agendaItem.properties["Deadline"] and agendaItem.properties["Deadline"]:match(" [%.%+]+[0-9]+[a-z]")) then
							agendaItem.logbookItems = common.getLogbookEntries(file_content, lineNumber)
						end
					end

					table.insert(agendaItems, agendaItem)
				end
			end
		end
	end

	return agendaItems
end


----------------FOLD LOGBOOK DETAILS FOR EXPRESSION FOLDING----------------
common.fold_details = function()
	local line = vim.fn.getline(vim.v.lnum)
	if string.match(line, "<details logbook>") then
		vim.b.insideLogbook = true
		return ">1"
	elseif string.match(line, "</details>") then
		vim.b.insideLogbook = false
		return "<1"
	end

	if vim.b.insideLogbook then
		return 1
	end

	return "="
end

return common
