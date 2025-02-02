--functions and variables that are used in multiple files
M = {}

local vim = vim

-----------VARS--------------
M.oneDay = 24*60*60 --one day in seconds
M.config = {}

------------GET MAP ITEM COUNT--------------
M.getMapItemCount = function(map)
    local count = 0
    for _, _ in pairs(map) do
        count = count + 1
    end
    return count
end

M.splitFoldmarkerString = function()
    local result = {}
    for item in string.gmatch(M.config.foldmarker, "([^,]+)") do
        table.insert(result, item)
    end
    return result
end


local function isDirectory(path)
    local stat = vim.loop.fs_stat(path)
    return stat and stat.type == 'directory'
end

M.listAgendaFiles = function()
    local agendaFiles = {}
    for _,agendaFilePath in ipairs(M.config.agendaFiles) do

        agendaFilePath = vim.fn.expand(agendaFilePath)

        if isDirectory(agendaFilePath) then
            local fileList = vim.fn.systemlist("rg --files --glob '!.*' --glob '*.md' --glob '*.mdx' " .. agendaFilePath)
            for _,oneFile in ipairs(fileList) do
                table.insert(agendaFiles, oneFile)
            end
        else
            table.insert(agendaFiles, agendaFilePath)
        end
    end

    return agendaFiles
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

            occurrence = occurrence + M.oneDay
        end

        --After the first same weekday found, increase it by one week until it has the same day with given unixTime
        while occurrence <= unixTime do
            occurrenceCount = occurrenceCount + 1

            occurrence = occurrence + M.oneDay * 7
        end

    --Start from the end
    elseif startPoint == -1 then
        --To get the last day of this month, get the next month's first day, then subtract one day, finally, convert the new result to the table.
        local lastDayOfMonth = os.time(os.date("*t", os.time({year = timeTable.year, month = timeTable.month+1, day=1}) - M.oneDay))

        --Find the last same weekday of the same month
        local occurrence = lastDayOfMonth
        while os.date("*t", occurrence).wday ~= timeTable.wday do

            occurrence = occurrence - M.oneDay
        end

        --After the last same weekday found, decrease it by one week until it has the same day with given unixTime
        while unixTime <= occurrence do
            occurrenceCount = occurrenceCount + 1

            occurrence = occurrence - M.oneDay * 7
        end
    end

    return occurrenceCount
--\}}}
end

M.parseTaskTime = function(timeString)
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

        --Currently, number is ignored.
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

                    taskTimeMap["nextUnixTime"] = taskTimeMap["nextUnixTime"] + M.oneDay
                end

            elseif repeatInterval=="z" then
                --Weekday's occurrence count in the month from the month's end to the taskUnixTime
                local occurrenceCount = getWeekdayOccurenceCountInMonthUntilGivenDate(-1,taskUnixTime)

                taskTimeMap["nextUnixTime"] = os.time({year=taskYear+num, month=taskMonth, day=1})
                --Do a loop until the nexUnixTime's weekday and its occurrenceCount is equal to task's
                while os.date("*t", taskTimeMap["nextUnixTime"]).wday ~= taskWeekday and
                occurrenceCount ~= getWeekdayOccurenceCountInMonthUntilGivenDate(-1, taskTimeMap["nextUnixTime"]) do

                    taskTimeMap["nextUnixTime"] = taskTimeMap["nextUnixTime"] + M.oneDay
                end
            end

        end

        -----------------

        --if the repeat type is "++" and the next unix time is in the past, increase it until it shıws a future time.
        if repeatType=="++" and taskTimeMap["nextUnixTime"] < currentUnixTime then
                local taskDateWithDetails = os.date("*t", taskUnixTime)
                while true do
                    local nextUnixTime = taskTimeMap["nextUnixTime"] + M.oneDay
                    taskTimeMap["nextUnixTime"] = nextUnixTime

                    if currentUnixTime < taskTimeMap["nextUnixTime"] then
                        if repeatInterval=="d" then
                            break

                        elseif repeatInterval=="w" then
                            if taskDateWithDetails.wday == os.date("*t",nextUnixTime).wday then
                                break
                            end

                        elseif repeatInterval=="m" then
                            if taskDateWithDetails.day == os.date("*t",nextUnixTime).day then
                                break
                            end

                        elseif repeatInterval=="y" then
                            if taskDateWithDetails.month == os.date("*t",nextUnixTime).month and
                            taskDateWithDetails.day == os.date("*t",nextUnixTime).day then
                                break
                            end

                        elseif repeatInterval=="x" or repeatInterval=="z" then
                            if taskDateWithDetails.year < os.date("*t",nextUnixTime).year and
                            taskDateWithDetails.wday == os.date("*t",nextUnixTime).wday and
                            taskDateWithDetails.month == os.date("*t",nextUnixTime).month then
                                if repeatInterval=="x" and
                                getWeekdayOccurenceCountInMonthUntilGivenDate(1,nextUnixTime) == getWeekdayOccurenceCountInMonthUntilGivenDate(1,taskUnixTime) then
                                    break
                                elseif repeatInterval=="z" and
                                getWeekdayOccurenceCountInMonthUntilGivenDate(-1,nextUnixTime) == getWeekdayOccurenceCountInMonthUntilGivenDate(-1,taskUnixTime) then
                                    break
                                end
                            end
                        end
                    end
                end
        end

        taskTimeMap["nextTimeStr"] = os.date("%Y-%m-%d %H:%M", taskTimeMap["nextUnixTime"]) .." +"..repeatNum..repeatInterval
    end

    return taskTimeMap
--\}}}
end

--Checks if the given date is in the range of the given task time string
--wantedDateStr's format: 2000-12-30
--if returned value is false, it means that date is a free time
M.IsDateInRangeOfGivenRepeatingTimeStr = function(repeatingTimeStr, wantedDateStr)
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
            local repeatingTimeDSE = math.floor(repeatingTimeUnix / M.oneDay)
            local wantedDateDSE = math.floor(wantedDateUnix / M.oneDay)

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
M.getTaskProperties = function(ContentLinesArr, taskLineNum)
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
            properities[key]={propertyLineNum, value}

            propertyLineNum=propertyLineNum+1

            --print("Property: "..key.." "..value)
        else
          break
        end

        ::continue::
    end

    return properities
end

-------------ADD A PROPERTY TO A TASK IN THE CURRENT BUFFER-----------------
--add a new property to the task or update the existing one
M.addPropertyToBufTask = function(taskLineNum, key, value)
    local currentBuf = vim.api.nvim_get_current_buf()
    local currentBufLines = vim.api.nvim_buf_get_lines(currentBuf, 0, -1, true)

    local taskProperties = M.getTaskProperties(currentBufLines, taskLineNum)

    --if it exists, update
    if taskProperties[key] then
        local propertyLineNum = taskProperties[key][1]
        vim.api.nvim_buf_set_lines(0, propertyLineNum-1, propertyLineNum, false, { string.format("- %s: `%s`", key, value) })

    --if it does not exist, create
    else
        local newProperty = string.format("- %s: `%s`", key, value)

        table.insert(currentBufLines, taskLineNum+1, newProperty)
        vim.api.nvim_buf_set_lines(currentBuf, 0, -1, false, currentBufLines)
    end
end

--------------SAVE TO THE LOGBOOK---------------
M.saveToLogbook = function(taskLineNum, logStr)
    local lineNum = taskLineNum+1

    local logbookExists = false
    local logbookStart=0

    local currentBuf = vim.api.nvim_get_current_buf()
    local currentBufLines = vim.api.nvim_buf_get_lines(currentBuf, 0, -1, true)

    --determine if the task has a logbook
    while true do
        local lineContent = vim.fn.getline(lineNum)

        --if reached to another header or end of the file, stop
        if #currentBufLines < lineNum or lineContent:match(" *#+") then
            break
        end

        if lineContent:match(".*<details logbook>") then
            logbookStart = lineNum
            logbookExists = true
            break

        end

        lineNum=lineNum+1
    end

    if logbookExists then
        --there must be a line space between <details logbook> html tag and markdown. So we put new markdown log to two line under the details tag
        table.insert(currentBufLines, logbookStart+2, "  "..logStr)

    --if logbook does not found, create one and insert the logStr
    else
        --insert below properties
        local properties = M.getTaskProperties(currentBufLines, taskLineNum)
        local propertyCount = M.getMapItemCount(properties)

        local newLines = {}
        table.insert(newLines, "<details logbook><!--"..M.splitFoldmarkerString()[1].."-->")
        table.insert(newLines, "")
        table.insert(newLines, "  "..logStr)
        table.insert(newLines, "<!--"..M.splitFoldmarkerString()[2].."--></details>")

        for i, newLine in ipairs(newLines) do
            table.insert(currentBufLines, taskLineNum + propertyCount + i, newLine)
        end
    end

    vim.api.nvim_buf_set_lines(currentBuf, 0, -1, false, currentBufLines)
end

---------------GET LOGBOOK ENTRIES---------------
M.getLogbookEntries = function(ContentLinesArr, taskLineNum)
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
            --example logbook line: - [x] `2022-12-30 18:80` `(6/10)`
            local status, text = line:match(" *- %[(.+)%] (.*)")

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

return M
