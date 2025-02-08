local config = require("md-agenda.config")

local common = require("md-agenda.common")

local vim = vim

local agendaView = {}

local filterByTags = {} --{"event", "work"}
--function for filtering tasks based on tags
local function includeTask(taskLine)
    --if tag filter is empty,
    if #filterByTags == 0 then
        return true

    --if tag filter has tags for filter
    else
        local matchCount = 0
        for _, filterTag in ipairs(filterByTags) do
            if taskLine:match("#"..filterTag) or taskLine:match(":"..filterTag..":") or taskLine:match("# "..filterTag..":") then
                matchCount = matchCount + 1
            end
        end

        if #filterByTags == matchCount then
            return true
        end
    end

    return false
end

------------------

--Function to show times in agenda items only if they are different than 00:00
local function showTimeStrInAgendaItem(timeStr)
    local hourandminute = timeStr:match("([0-9]+:[0-9]+)")
    if hourandminute ~= "00:00" then
        return hourandminute.." | "

    else return "" end
end

--Function to show remaining days or how many days passed from deadline or scheduled time.
local function remainingOrPassedDays(fromDate ,targetDate)
    local fYear, fMonth, fDay = fromDate:match("([0-9]+)-([0-9]+)-([0-9]+)")
    local fUnixTime = os.time({year=fYear, month=fMonth, day=fDay})

    local tYear, tMonth, tDay = targetDate:match("([0-9]+)-([0-9]+)-([0-9]+)")
    local tUnixTime = os.time({year=tYear, month=tMonth, day=tDay})

    local daysBetweenThem = math.floor((tUnixTime - fUnixTime) / common.oneDay)

    --if the target date was in the past
    if daysBetweenThem < 0 then
        return -1*daysBetweenThem.."d ago"
    --if the target time is in the future
    else
        return daysBetweenThem.."d left"
    end
end

--Only renewing the cache in agenda view open. Pagination uses already existing cache.
local agendaItemsCache = {}

---------------AGENDA VIEW---------------
local function getAgendaTasks(startTimeUnix, endTimeUnix)
    local currentDateTable = os.date("*t")
    local currentDateStr = currentDateTable.year.."-"..string.format("%02d", currentDateTable.month).."-"..string.format("%02d", currentDateTable.day)
    -- Set hours, minutes, and seconds to zero
    currentDateTable.hour, currentDateTable.min, currentDateTable.sec = 0, 0, 0
    local currentDayStart = os.time(currentDateTable)

    local sortedDates = {}
    local days = {}

    local i = 0
    while true do
        if startTimeUnix + (i * common.oneDay) > endTimeUnix then
            break
        end

        local nextDate = os.date("%Y-%m-%d", startTimeUnix + (i * common.oneDay)) -- Get the date for today + i days
        days[nextDate]={exists=true, tasks={}}
        table.insert(sortedDates,nextDate)
        i=i+1
    end

    --[[--TODO: focus on the hour and minutes in day agenda
    local dayAgenda=false
    if startTimeUnix == endTimeUnix then
        dayAgenda=true
    end]]

    for _, agendaItem in ipairs(agendaItemsCache) do
        if agendaItem.agendaItem[1]~="HABIT" and includeTask(agendaItem.agendaItem[3]) then

            ------------------
            local parsedScheduled
            if agendaItem.properties["Scheduled"] then
                parsedScheduled = common.parseTaskTime(agendaItem.properties["Scheduled"])

                if not parsedScheduled then print("for some reason, scheduled could not correctly parsed") return {} end
            end

            local parsedDeadline
            if agendaItem.properties["Deadline"] then
                parsedDeadline = common.parseTaskTime(agendaItem.properties["Deadline"])

                if not parsedDeadline then print("for some reason, deadline could not correctly parsed") return {} end
            end
            ------------------

            --If only Scheduled time exists
            if agendaItem.properties["Scheduled"] and (not agendaItem.properties["Deadline"]) then
                local scheduledDate = agendaItem.properties["Scheduled"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
                if days[scheduledDate] and days[scheduledDate]["exists"] then
                    --if its info, do not show "Scheduled:" text
                    if agendaItem.agendaItem[1]=="INFO" then
                        table.insert(days[scheduledDate]["tasks"],
                            showTimeStrInAgendaItem(agendaItem.properties["Scheduled"])
                            ..agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2])
                    else
                        table.insert(days[scheduledDate]["tasks"],
                            "Scheduled: "..showTimeStrInAgendaItem(agendaItem.properties["Scheduled"])..
                            agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2])
                    end
                end

                --insert text to current date if the current date is close to task scheduled date by n days
                --also if current date is not higher than the task deadline originally
                if common.isTodoItem(agendaItem.agendaItem[1]) and days[currentDateStr] and (currentDayStart < parsedScheduled["unixTime"]) and
                (currentDayStart + ((config.config.remindScheduledInDays+1)*common.oneDay) > parsedScheduled["unixTime"]) then

                    table.insert(days[currentDateStr]["tasks"],
                        agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
                        " (SC: "..remainingOrPassedDays(currentDateStr, agendaItem.properties["Scheduled"])..")")
                end

                --show the task in today until its done, as it has a scheduled date but no deadline
                if common.isTodoItem(agendaItem.agendaItem[1]) and days[currentDateStr] and (parsedScheduled["unixTime"] < currentDayStart) then
                    table.insert(days[currentDateStr]["tasks"],
                        agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
                        " (SC: "..remainingOrPassedDays(currentDateStr, agendaItem.properties["Scheduled"])..")"
                    )
                end

            --If only Deadline exists
            elseif (not agendaItem.properties["Scheduled"]) and agendaItem.properties["Deadline"] then
                --insert text to deadline
                local deadlineDate = agendaItem.properties["Deadline"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
                if days[deadlineDate] and days[deadlineDate]["exists"] then
                    table.insert(days[deadlineDate]["tasks"],
                        "Deadline: "..showTimeStrInAgendaItem(agendaItem.properties["Deadline"])..
                        agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2])
                end
                --insert text to current date if the current date is close to task deadline by n days
                --also if current date is not higher than the task deadline originally
                if common.isTodoItem(agendaItem.agendaItem[1]) and days[currentDateStr] and (currentDayStart < parsedDeadline["unixTime"]) and
                (currentDayStart + ((config.config.remindDeadlineInDays+1)*common.oneDay) > parsedDeadline["unixTime"]) then

                    table.insert(days[currentDateStr]["tasks"],
                        agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
                        " (DL: "..remainingOrPassedDays(currentDateStr, agendaItem.properties["Deadline"])..")")
                end

            --If both Scheduled and Deadline do exist
            elseif agendaItem.properties["Scheduled"] and agendaItem.properties["Deadline"] then
                --insert text to scheduled date
                local scheduledDate=agendaItem.properties["Scheduled"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
                if days[scheduledDate] and days[scheduledDate]["exists"] then
                    if agendaItem.agendaItem[1] == "INFO" then
                        table.insert(days[scheduledDate]["tasks"],
                            agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
                            " (DL: "..remainingOrPassedDays(scheduledDate, agendaItem.properties["Deadline"])..")")
                    else
                        table.insert(days[scheduledDate]["tasks"],
                            "Scheduled: "..agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
                            " (DL: "..remainingOrPassedDays(scheduledDate, agendaItem.properties["Deadline"])..")")
                    end
                end
                --insert text to deadline date
                local deadlineDate=agendaItem.properties["Deadline"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
                if days[deadlineDate] and days[deadlineDate]["exists"] then
                    table.insert(days[deadlineDate]["tasks"],
                        "Deadline: "..showTimeStrInAgendaItem(agendaItem.properties["Deadline"])..
                        agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2])
                end
                --insert text to current date if its between scheduled and deadline date
                if common.isTodoItem(agendaItem.agendaItem[1]) and days[currentDateStr] and
                (currentDayStart < parsedDeadline["unixTime"]) and (parsedScheduled["unixTime"] < currentDayStart) and
                currentDateStr ~= agendaItem.properties["Deadline"]:match("([0-9]+%-[0-9]+%-[0-9]+)") and
                currentDateStr ~= agendaItem.properties["Scheduled"]:match("([0-9]+%-[0-9]+%-[0-9]+)") then
                    table.insert(days[currentDateStr]["tasks"],
                        agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
                        " (DL: "..remainingOrPassedDays(currentDateStr, agendaItem.properties["Deadline"])..")")
                end

                --insert text to current date if the current date is close to task scheduled date by n days
                --also if current date is not higher than the task deadline originally
                if common.isTodoItem(agendaItem.agendaItem[1]) and days[currentDateStr] and (currentDayStart < parsedScheduled["unixTime"]) and
                (currentDayStart + ((config.config.remindScheduledInDays+1)*common.oneDay) > parsedScheduled["unixTime"]) then

                    table.insert(days[currentDateStr]["tasks"],
                        agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
                        " (SC: "..remainingOrPassedDays(currentDateStr, agendaItem.properties["Scheduled"])..")")
                end

            --If not Scheduled nor Deadline exists
            elseif (not agendaItem.properties["Scheduled"]) and (not agendaItem.properties["Deadline"]) then
                --show the task in today if its not finished
                if config.config.showNonTimeawareTasksToday and
                common.isTodoItem(agendaItem.agendaItem[1]) and days[currentDateStr] then
                    table.insert(days[currentDateStr]["tasks"],
                        agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2])
                end
            end


            --if task is a repeating task (repeat indicator on the scheduled), show the incoming days at the agenda until the deadline
            if (common.isTodoItem(agendaItem.agendaItem[1]) or agendaItem.agendaItem[1] == "INFO") and parsedScheduled and parsedScheduled["nextUnixTime"] then
                for _, sortedDate in ipairs(sortedDates) do
                    local sdYear, sdMonth, sdDay = sortedDate:match("([0-9]+)-([0-9]+)-([0-9]+)")
                    local sdUnixTime = os.time({year=sdYear, month=sdMonth, day=sdDay})

                    --break the loop if the sortedDate exceeds the deadline
                    if parsedDeadline and parsedDeadline["unixTime"] and sdUnixTime >= parsedDeadline["unixTime"] then
                        break
                    end

                    --Only show in the future dates and not in the scheduled day as its already inserted to that day in the above codes.
                    if parsedScheduled["unixTime"] <= sdUnixTime and
                    agendaItem.properties["Scheduled"]:match("([0-9]+%-[0-9]+%-[0-9]+)") ~= sortedDate then
                        if common.IsDateInRangeOfGivenRepeatingTimeStr(agendaItem.properties["Scheduled"], sortedDate) then
                            if agendaItem.agendaItem[1] == "INFO" then
                                table.insert(days[sortedDate]["tasks"],
                                    showTimeStrInAgendaItem(agendaItem.properties["Scheduled"])..
                                    agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2])
                            else
                                table.insert(days[sortedDate]["tasks"],
                                    "Scheduled: "..showTimeStrInAgendaItem(agendaItem.properties["Scheduled"])..
                                    agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2])
                            end
                        end
                    end
                end
            end

            --if task is a repeating task (repeat indicator on the deadline), show the incoming days at the agenda.
            if (common.isTodoItem(agendaItem.agendaItem[1]) or agendaItem.agendaItem[1] == "INFO") and parsedDeadline and parsedDeadline["nextUnixTime"] then
                for _, sortedDate in ipairs(sortedDates) do
                    local sdYear, sdMonth, sdDay = sortedDate:match("([0-9]+)-([0-9]+)-([0-9]+)")
                    local sdUnixTime = os.time({year=sdYear, month=sdMonth, day=sdDay})

                    --Only show in future dates
                    if parsedDeadline["unixTime"] <= sdUnixTime and
                    agendaItem.properties["Deadline"]:match("([0-9]+%-[0-9]+%-[0-9]+)") ~= sortedDate then
                        if common.IsDateInRangeOfGivenRepeatingTimeStr(agendaItem.properties["Deadline"], sortedDate) then
                            table.insert(days[sortedDate]["tasks"],
                                "Deadline: "..showTimeStrInAgendaItem(agendaItem.properties["Deadline"])..
                                agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]
                            )
                        end
                    end
                end
            end

            --If a task is done, show the time in Completion property in the agenda view.
            if agendaItem.properties["Completion"] then
                for _,sortedDate in ipairs(sortedDates) do
                    if agendaItem.properties["Completion"]:match("([0-9]+%-[0-9]+%-[0-9]+)") == sortedDate then
                            table.insert(days[sortedDate]["tasks"],
                                "Completion: "..showTimeStrInAgendaItem(agendaItem.properties["Completion"])..
                                agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2])
                    end
                end
            end

            --Show logbook entries in the graph
            if agendaItem.logbookItems then
                for logbookDate,logbookItem in pairs(agendaItem.logbookItems) do
                    for _,sortedDate in ipairs(sortedDates) do
                        if logbookDate == sortedDate then
                            table.insert(days[sortedDate]["tasks"],
                                "Repeat: "..showTimeStrInAgendaItem(logbookItem[2])..
                                agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2])
                        end
                    end
                end
            end

        end
    end

    return {sortedDates, days}
end

local relativePage = 0
local function renderAgendaView()
    vim.cmd("new")

    local bufNumber = vim.api.nvim_get_current_buf()

    vim.cmd("highlight date guifg="..config.config.titleColor.." ctermfg="..config.config.titleColor)
    vim.cmd("syntax match date /^- .*$/")

    vim.cmd("highlight todo guifg="..config.config.todoTypeColor.." ctermfg="..config.config.todoTypeColor)
    vim.cmd("syntax match todo /TODO/")

    vim.cmd("highlight habit guifg="..config.config.habitTypeColor.." ctermfg="..config.config.habitTypeColor)
    vim.cmd("syntax match habit /HABIT/")

    vim.cmd("highlight due guifg="..config.config.dueTypeColor.." ctermfg="..config.config.dueTypeColor)
    vim.cmd("syntax match due /DUE/")

    vim.cmd("highlight done guifg="..config.config.doneTypeColor.." ctermfg="..config.config.doneTypeColor)
    vim.cmd("syntax match done /DONE/")

    vim.cmd("highlight info guifg="..config.config.infoTypeColor.." ctermfg="..config.config.infoTypeColor)
    vim.cmd("syntax match info /INFO/")

    vim.cmd("highlight completionColor guifg="..config.config.completionColor.." ctermfg="..config.config.completionColor)
    vim.cmd("syntax match completionColor /Completion:/")
    vim.cmd("syntax match completionColor /Repeat:/")

    vim.cmd("highlight deadline guifg="..config.config.deadlineTimeColor.." ctermfg="..config.config.deadlineTimeColor)
    vim.cmd("syntax match deadline /Deadline:/")
    vim.cmd("syntax match deadline /(DL: \\+.*)/")

    vim.cmd("highlight cancelledTask guifg="..config.config.cancelledTypeColor.." ctermfg="..config.config.cancelledTypeColor)
    vim.cmd("syntax match cancelledTask /CANCELLED/")

    vim.cmd("highlight scheduled guifg="..config.config.scheduledTimeColor.." ctermfg="..config.config.scheduledTimeColor)
    vim.cmd("syntax match scheduled /Scheduled:/")
    vim.cmd("syntax match scheduled /(SC: \\+.*)/")

    vim.cmd("highlight tag guifg="..config.config.tagColor.." ctermfg="..config.config.tagColor)
    vim.cmd("syntax match tag /\\#[a-zA-Z0-9]\\+/")
    vim.cmd("syntax match tag /:[a-zA-Z0-9:]\\+:/")

    for customType, itsColor in pairs(config.config.customTodoTypes) do
        vim.cmd("highlight "..customType.." guifg="..itsColor.." ctermfg="..itsColor)
        vim.cmd("syntax match "..customType.." /"..customType.."/")
    end

    local renderLines = {}

    -- Get the current date and time
    local currentDateTable = os.date("*t")
    local currentDateStr = currentDateTable.year.."-"..string.format("%02d", currentDateTable.month).."-"..string.format("%02d", currentDateTable.day)

    -- Set hours, minutes, and seconds to zero
    currentDateTable.hour, currentDateTable.min, currentDateTable.sec = 0, 0, 0
    -- Convert the table back to a timestamp
    local currentDayStart = os.time(currentDateTable)

    --add some comments here, how pagination works can be easily forgotten
    --pagination
    local pageStart = currentDayStart + common.oneDay * config.config.agendaViewPageItems * relativePage
    local pageEnd = pageStart + common.oneDay * (config.config.agendaViewPageItems - 1)

    local dayNTasks = getAgendaTasks(pageStart, pageEnd)

    table.insert(renderLines, "Agenda View - Page: "..relativePage)

    for _,dateStr in ipairs(dayNTasks[1]) do

        --format date for better readability
        local year,month,day=dateStr:match("([0-9]+)-([0-9]+)-([0-9]+)")
        local taskTimeTable = {
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = 0, min = 0, sec = 0,
            isdst = false  -- daylight saving time flag
        }
        local dayUnixTime = os.time(taskTimeTable)
        local humanDate = os.date("%d %B(%m) %Y - %A",dayUnixTime)

        if currentDateStr == dateStr then
            table.insert(renderLines, "- (Today) "..humanDate)
        else
            table.insert(renderLines, "- "..humanDate)
        end

        for _,taskStr in ipairs(dayNTasks[2][dateStr]["tasks"]) do
            table.insert(renderLines, "  "..taskStr)
        end

    end

    vim.api.nvim_buf_set_lines(0, 0, -1, false, renderLines)

    --disable modifying
    vim.api.nvim_buf_set_option(bufNumber, "readonly", true)
    vim.api.nvim_buf_set_option(bufNumber, "modifiable", false)
    vim.api.nvim_buf_set_option(bufNumber, "modified", false)

    vim.keymap.set('n', '<Right>', function()
        relativePage=relativePage+1
        vim.cmd('bd')
        renderAgendaView()
    end, { buffer = bufNumber, noremap = true, silent = true })

    vim.keymap.set('n', '<Left>', function()
        relativePage=relativePage-1
        vim.cmd('bd')
        renderAgendaView()
    end, { buffer = bufNumber, noremap = true, silent = true })

    vim.keymap.set('n', '<Esc>', function()vim.cmd('bd')
    end, { buffer = bufNumber, noremap = true, silent = true })
end

agendaView.agendaView = function()
    filterByTags={};
    agendaItemsCache = common.getAgendaItems("")
    renderAgendaView()
end

agendaView.agendaViewWTF = function(opts)
    local args = {}
    for arg in opts.args:gmatch("[a-zA-Z0-9]+") do
        table.insert(args, arg)
    end
    filterByTags = args

    agendaItemsCache = common.getAgendaItems("")
    renderAgendaView()
end

agendaView.nextAgendaPage = function ()
    print("This command is removed. Please use regular arrow keys to navigate in the agenda view.")
end

agendaView.prevAgendaPage = function ()
    print("This command is removed. Please use regular arrow keys to navigate in the agenda view.")
end

return agendaView
