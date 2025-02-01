local common = require("md-agenda.common")

local vim = vim

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

    --[[--focus on the hour and minutes in day agenda
    local dayAgenda=false
    if startTimeUnix == endTimeUnix then
        dayAgenda=true
    end]]

    for _,agendaFilePath in ipairs(common.listAgendaFiles()) do
        local file_content = vim.fn.readfile(agendaFilePath)
        if file_content then
            --also get file header
            local lineNumber = 0
            for _,line in ipairs(file_content) do
                lineNumber = lineNumber+1

                local taskType,title = line:match("^#+ (.+): (.*)")
                if (taskType=="TODO" or taskType=="DONE" or taskType=="DUE" or taskType=="INFO") and title then
                    local taskProperties = common.getTaskProperties(file_content, lineNumber)

                    --------------------------

                    local scheduledTimeStr, parsedScheduled
                    local scheduled=taskProperties["Scheduled"]
                    if scheduled then
                        scheduledTimeStr = scheduled[2]
                        parsedScheduled = common.parseTaskTime(scheduledTimeStr)

                        if not parsedScheduled then print("for some reason, scheduled could not correctly parsed") return end
                    end

                    local deadlineTimeStr, parsedDeadline
                    local deadline=taskProperties["Deadline"]
                    if deadline then
                        deadlineTimeStr = deadline[2]
                        parsedDeadline = common.parseTaskTime(deadlineTimeStr)

                        if not parsedDeadline then print("for some reason, deadline could not correctly parsed") return end
                    end

                    --------------------------

                    --if only scheduled exists
                    if scheduled and (not deadline) then
                        local scheduledDate=scheduledTimeStr:match("([0-9]+%-[0-9]+%-[0-9]+)")
                        if days[scheduledDate] and days[scheduledDate]["exists"] then
                            table.insert(days[scheduledDate]["tasks"], "Scheduled: "..scheduledTimeStr:match("([0-9]+:[0-9]+)").." | "..taskType.." "..title)
                        end

                        --show the task in today until its done, as it has a scheduled date but no deadline
                        if days[currentDateStr] and (parsedScheduled["unixTime"] < currentDayStart) and taskType=="TODO" then
                            table.insert(days[currentDateStr]["tasks"], taskType.." "..title.." (SC AT: "..os.date("%Y-%m-%d %H:%M",parsedScheduled["unixTime"])..")")
                        end

                    --if only deadline exists
                    elseif deadline and (not scheduled) then
                        --insert text to deadline
                        local deadlineDate=deadlineTimeStr:match("([0-9]+%-[0-9]+%-[0-9]+)")
                        if days[deadlineDate] and days[deadlineDate]["exists"] then
                            table.insert(days[deadlineDate]["tasks"], "Deadline: "..deadlineTimeStr:match("([0-9]+:[0-9]+)").." | "..taskType.." "..title)
                        end
                        --insert text to current date if the current date is close to task deadline by n days
                        --also if current date is not higher than the task deadline originally
                        if days[currentDateStr] and (currentDayStart < parsedDeadline["unixTime"]) and
                        (currentDayStart + ((common.config.remindDeadlineInDays+1)*common.oneDay) > parsedDeadline["unixTime"]) then

                            table.insert(days[currentDateStr]["tasks"], taskType.." "..title.." (DL AT: "..os.date("%Y-%m-%d %H:%M",parsedDeadline["unixTime"])..")")
                        end

                    --if both scheduled and deadline exists
                    elseif scheduled and deadline then
                        --insert text to scheduled date
                        local scheduledDate=scheduledTimeStr:match("([0-9]+%-[0-9]+%-[0-9]+)")
                        if days[scheduledDate] and days[scheduledDate]["exists"] then
                            table.insert(days[scheduledDate]["tasks"], "Scheduled: "..taskType.." "..title.." (DL AT: "..os.date("%Y-%m-%d %H:%M",parsedDeadline["unixTime"])..")")
                        end
                        --insert text to deadline date
                        local deadlineDate=deadlineTimeStr:match("([0-9]+%-[0-9]+%-[0-9]+)")
                        if days[deadlineDate] and days[deadlineDate]["exists"] then
                            table.insert(days[deadlineDate]["tasks"], "Deadline: "..deadlineTimeStr:match("([0-9]+:[0-9]+)").." | "..taskType.." "..title)
                        end
                        --insert text to current date if its between scheduled and deadline date
                        --TODO: what happens if the current day is the same day with deadline or scheduled time? fix it.
                        if days[currentDateStr] and
                        (currentDayStart < parsedDeadline["unixTime"]) and (parsedScheduled["unixTime"] < currentDayStart) then
                            table.insert(days[currentDateStr]["tasks"], taskType.." "..title.." (DL AT: "..os.date("%Y-%m-%d %H:%M",parsedDeadline["unixTime"])..")")
                        end

                    --if both scheduled and deadline times does not exist
                    elseif (not scheduled) and (not deadline) then
                        --show the task in today if its not finished
                        if days[currentDateStr] and taskType=="TODO" then
                            table.insert(days[currentDateStr]["tasks"], taskType.." "..title)
                        end
                    end

                    --if task is a repeating task (repeat indicator on the scheduled), show the incoming days at the agenda until the deadline
                    if parsedScheduled and parsedScheduled["nextUnixTime"] then
                        for _, sortedDate in ipairs(sortedDates) do
                            local sdYear, sdMonth, sdDay = sortedDate:match("([0-9]+)-([0-9]+)-([0-9]+)")
                            local sdUnixTime = os.time({year=sdYear, month=sdMonth, day=sdDay})

                            --break the loop if the sortedDate exceeds the deadline
                            if parsedDeadline and parsedDeadline["unixTime"] and sdUnixTime >= parsedDeadline["unixTime"] then
                                break
                            end

                            --Only show in future dates
                            if parsedScheduled["unixTime"] <= sdUnixTime then
                                if common.IsDateInRangeOfGivenRepeatingTimeStr(scheduledTimeStr, sortedDate) then
                                    table.insert(days[sortedDate]["tasks"], "Scheduled: "..scheduledTimeStr:match("([0-9]+:[0-9]+)").." | "..taskType.." "..title)
                                end
                            end
                        end
                    end

                    --if task is a repeating task (repeat indicator on the deadline), show the incoming days at the agenda.
                    if parsedDeadline and parsedDeadline["nextUnixTime"] then
                        for _, sortedDate in ipairs(sortedDates) do
                            local sdYear, sdMonth, sdDay = sortedDate:match("([0-9]+)-([0-9]+)-([0-9]+)")
                            local sdUnixTime = os.time({year=sdYear, month=sdMonth, day=sdDay})

                            --Only show in future dates
                            if parsedDeadline["unixTime"] <= sdUnixTime then
                                if common.IsDateInRangeOfGivenRepeatingTimeStr(deadlineTimeStr, sortedDate) then
                                    table.insert(days[sortedDate]["tasks"], "Deadline: "..deadlineTimeStr:match("([0-9]+:[0-9]+)").." | "..taskType.." "..title)
                                end
                            end
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

    vim.cmd("highlight date guifg=yellow ctermfg=yellow")
    vim.cmd("syntax match date /^-\\+ .*$/")

    vim.cmd("highlight todo guifg=cyan ctermfg=cyan")
    vim.cmd("syntax match todo /TODO/")

    vim.cmd("highlight habit guifg=blue ctermfg=blue")
    vim.cmd("syntax match habit /HABIT/")

    vim.cmd("highlight due guifg=grey ctermfg=grey")
    vim.cmd("syntax match due /DUE/")

    vim.cmd("highlight done guifg=green ctermfg=green")
    vim.cmd("syntax match done /DONE/")
    
    vim.cmd("highlight info guifg=lightgreen ctermfg=lightgreen")
    vim.cmd("syntax match info /INFO/")
    
    vim.cmd("highlight deadline guifg=red ctermfg=red")
    vim.cmd("syntax match deadline /Deadline:/")
    vim.cmd("syntax match deadline /(DL AT: \\+.*)/")

    vim.cmd("highlight scheduled guifg=cyan ctermfg=cyan")
    vim.cmd("syntax match scheduled /Scheduled:/")
    vim.cmd("syntax match scheduled /(SC AT: \\+.*)/")

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
    local pageStart = currentDayStart + common.oneDay * common.config.agendaViewPageItems * relativePage
    local pageEnd = pageStart + common.oneDay * (common.config.agendaViewPageItems - 1)

    local dayNTasks = getAgendaTasks(pageStart, pageEnd)

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
            table.insert(renderLines, "    "..taskStr)
        end

    end

    vim.api.nvim_buf_set_lines(0, 0, -1, false, renderLines)

    --disable modifying
    vim.api.nvim_buf_set_option(bufNumber, "readonly", true)
    vim.api.nvim_buf_set_option(bufNumber, "modifiable", false)
    vim.api.nvim_buf_set_option(bufNumber, "modified", false)
end

vim.api.nvim_create_user_command('AgendaView', function()renderAgendaView()end, {})

vim.api.nvim_create_user_command('NextAgendaPage', function()
    relativePage=relativePage+1
    vim.cmd('q')
    renderAgendaView()
end, {})

vim.api.nvim_create_user_command('PrevAgendaPage', function()
    relativePage=relativePage-1
    vim.cmd('q')
    renderAgendaView()
end, {})
