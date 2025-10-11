local config = require("md-agenda.config")

local common = require("md-agenda.common")

local taskAction = require("md-agenda.checkTask")
local updateProgress = require("md-agenda.updateProgress")

local vim = vim

local habitView = {}

---------------HABIT VIEW---------------
local function getHabitTasks(startTimeUnix, endTimeUnix)
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
		days[nextDate]="ø" --it means task is not made

		table.insert(sortedDates,nextDate)
		i=i+1
	end

	--color today as brown
	if days[currentDateStr] then
		days[currentDateStr]="♅" --it means that the day is today
	end

	local habits = {}

	local agendaItems = common.getAgendaItems("")

	for _, agendaItem in ipairs(agendaItems) do
		if agendaItem.agendaItem[1] == "HABIT" then

			local habitDays = {}
			--copy days template map's values to this habit's days table
			for k, v in pairs(days) do
				habitDays[k] = v  -- Copy each key-value pair
			end

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

			--handle with free days between scheduled times based on intervals (repeat indicator)
			if parsedScheduled then
				for _, sortedDate in ipairs(sortedDates) do
					if not common.IsDateInRangeOfGivenRepeatingTimeStr(agendaItem.properties["Scheduled"], sortedDate) then
						habitDays[sortedDate]="⍣"
					end
				end
			end

			--insert logbook tasks to the days
			--as its not an array but map, we use pairs() instead of ipairs()
			for habitDay,log in pairs(agendaItem.logbookItems) do
				if habitDays[habitDay] then
					local habitStatus = log[1]

					if habitStatus == "DONE" then
						habitDays[habitDay] = "⊹" --it means that the habit is done that day
					elseif habitStatus == "PROGRESS" then
						habitDays[habitDay] = "¤" --it means that a progress has been made but habit goal could not be made
					end
				end
			end

			if agendaItem.properties["Scheduled"] then
				local scheduledDate=agendaItem.properties["Scheduled"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
				if habitDays[scheduledDate] then

					--if the task is scheduled in the past, show past schedulation in different color
					--and color today yellow
					if parsedScheduled["unixTime"] < currentDayStart then
						habitDays[scheduledDate]="⚨"
						habitDays[currentDateStr]="♁"--it means that the habit must be done that day
					else
						habitDays[scheduledDate]="♁" --it means that the habit must be done that day
					end
				end
			end

			if agendaItem.properties["Deadline"] then
				local deadlineDate=agendaItem.properties["Deadline"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
				if days[deadlineDate] then
					habitDays[deadlineDate]="♆" --it means that its the day of the end of the habit
				end
			end

			--habits={ {metadata={filepath, lineNum}, habit="do bla bla bla", streak=10, days={2024-04-20="-", 2024-04-21="+", ...}}, ...}
			table.insert(habits, {metadata={agendaItem.metadata[1], agendaItem.metadata[2]}, habit=agendaItem.agendaItem[2], days=habitDays})
		end
	end

	return {sortedDates, habits}
end

--type is habit or agenda
habitView.renderHabitView = function()
	--To refresh the previous buffer's content. (The buffer that is focused before the view buffer)
	local prevBufferNum = vim.api.nvim_get_current_buf()

	if config.config.habitViewSplitOrientation == "vertical" then
		vim.cmd("vnew")
	else
		vim.cmd("new")
	end
	vim.cmd("set cursorline")

	local bufNumber = vim.api.nvim_get_current_buf()

	vim.cmd("highlight progressmade guibg="..config.config.habitProgressColor.." ctermbg="..config.config.habitProgressColor.." guifg="..config.config.habitProgressColor.." ctermfg="..config.config.habitProgressColor)
	vim.cmd("syntax match progressmade /¤/")

	vim.cmd("highlight mustdone guibg="..config.config.habitScheduledColor.." ctermbg="..config.config.habitScheduledColor.." guifg="..config.config.habitScheduledColor.." ctermfg="..config.config.habitScheduledColor)
	vim.cmd("syntax match mustdone /♁/")

	vim.cmd("highlight pastscheduled guibg="..config.config.habitPastScheduledColor.." ctermbg="..config.config.habitPastScheduledColor.." guifg="..config.config.habitPastScheduledColor.." ctermfg="..config.config.habitPastScheduledColor)
	vim.cmd("syntax match pastscheduled /⚨/")

	vim.cmd("highlight habitdone guibg="..config.config.habitDoneColor.." ctermbg="..config.config.habitDoneColor.." guifg="..config.config.habitDoneColor.." ctermfg="..config.config.habitDoneColor)
	vim.cmd("syntax match habitdone /⊹/")

	vim.cmd("highlight notdone guibg="..config.config.habitNotDoneColor.." ctermbg="..config.config.habitNotDoneColor.." guifg="..config.config.habitNotDoneColor.." ctermfg="..config.config.habitNotDoneColor)
	vim.cmd("syntax match notdone /ø/")

	vim.cmd("highlight end guibg="..config.config.habitDeadlineColor.." ctermbg="..config.config.habitDeadlineColor.." guifg="..config.config.habitDeadlineColor.." ctermfg="..config.config.habitDeadlineColor)
	vim.cmd("syntax match end /♆/")

	vim.cmd("highlight noneed guibg="..config.config.habitFreeTimeColor.." ctermbg="..config.config.habitFreeTimeColor.." guifg="..config.config.habitFreeTimeColor.." ctermfg="..config.config.habitFreeTimeColor)
	vim.cmd("syntax match noneed /⍣/")

	vim.cmd("highlight today guibg=brown ctermbg=brown guifg=brown ctermfg=brown")
	vim.cmd("syntax match today /♅/")

	vim.cmd("highlight tag guifg="..config.config.tagColor.." ctermfg="..config.config.tagColor)
	vim.cmd("syntax match tag /\\#[a-zA-Z0-9]\\+/")
	vim.cmd("syntax match tag /:[a-zA-Z0-9:]\\+:/")

	local lineItemMetadataMap = {}

	local renderLines = {}

	local currentDateTable = os.date("*t")
	-- Set hours, minutes, and seconds to zero
	currentDateTable.hour, currentDateTable.min, currentDateTable.sec = 0, 0, 0
	local currentDayStart = os.time(currentDateTable)
	local currentDateStr = os.date("%Y-%m-%d", currentDayStart)

	--{sortedDates, habits}
	local dayNHabits = getHabitTasks(currentDayStart-common.oneDay*config.config.habitViewPastItems, currentDayStart+common.oneDay*config.config.habitViewFutureItems)

	local currentLine = 1
	table.insert(renderLines, "Habit View")

	--habits
	for _,habit in ipairs(dayNHabits[2]) do
		currentLine = currentLine + 1
		lineItemMetadataMap[currentLine] = {habit.metadata[1], habit.metadata[2]}
		table.insert(renderLines, habit.habit)

		local consistencyGraph = ""
		for _,dateStr in ipairs(dayNHabits[1]) do
			consistencyGraph = consistencyGraph .. habit.days[dateStr]
		end

		currentLine = currentLine + 1
		lineItemMetadataMap[currentLine] = {habit.metadata[1], habit.metadata[2]}
		table.insert(renderLines, consistencyGraph)
		--table.insert(renderLines, "")
	end

	vim.api.nvim_buf_set_lines(0, 0, -1, false, renderLines)

	--disable modifying
	vim.api.nvim_buf_set_option(bufNumber, "readonly", true)
	vim.api.nvim_buf_set_option(bufNumber, "modifiable", false)
	vim.api.nvim_buf_set_option(bufNumber, "modified", false)

	vim.keymap.set('n', '<Esc>', function()vim.cmd('bd')
	end, { buffer = bufNumber, noremap = true, silent = true })

	--Go to the task
	vim.keymap.set('n', '<Enter>', function()
		local cursorLineNum = vim.api.nvim_win_get_cursor(0)[1]
		if lineItemMetadataMap[cursorLineNum] then
			vim.cmd("bd")
			--go to the file of the task
			vim.cmd('edit '..lineItemMetadataMap[cursorLineNum][1])
			--go to the task line number
			vim.cmd(""..lineItemMetadataMap[cursorLineNum][2])
		else
			print("To check an item, place your cursor to the agenda item and rerun this command.")
		end
	end, { buffer = bufNumber, noremap = true, silent = true })

	--Update Progress--
	vim.api.nvim_buf_create_user_command(0, 'UpdateProgress', function()
		local cursorLineNum = vim.api.nvim_win_get_cursor(0)[1]
		if lineItemMetadataMap[cursorLineNum] then
			local progressCount = vim.fn.input("New Progress: ")
			if #progressCount == 0 then
				print("No change")
				return
			elseif not tonumber(progressCount) then
				print("Invalid progress count")
				return
			end
			local currentBufNum = vim.api.nvim_get_current_buf()
			updateProgress.updateTaskProgress(lineItemMetadataMap[cursorLineNum][1], lineItemMetadataMap[cursorLineNum][2], tonumber(progressCount), currentBufNum)
			--After the update, refresh the view
			vim.cmd('bd')
			habitView.renderHabitView()
			vim.cmd(tostring(cursorLineNum))
		else
			print("To update a progress, place your cursor to the agenda item and rerun this command.")
		end
	end, {})

	--Task checking command
	vim.api.nvim_buf_create_user_command(0, 'CheckTask', function()
		local cursorLineNum = vim.api.nvim_win_get_cursor(0)[1]
		if lineItemMetadataMap[cursorLineNum] then
			taskAction.taskAction(lineItemMetadataMap[cursorLineNum][1], lineItemMetadataMap[cursorLineNum][2], "check", prevBufferNum)
			--After the check, refresh the view
			vim.cmd('bd')
			habitView.renderHabitView()
			vim.cmd(tostring(cursorLineNum))
		else
			print("To check an item, place your cursor to the agenda item and rerun this command.")
		end
	end, {})
	--Task cancel command -- This is unnecessary for the habit view as we cannot cancel them. I added this for the sake of consistency.
	vim.api.nvim_buf_create_user_command(0, 'CancelTask', function()
		local cursorLineNum = vim.api.nvim_win_get_cursor(0)[1]
		if lineItemMetadataMap[cursorLineNum] then
			taskAction.taskAction(lineItemMetadataMap[cursorLineNum][1], lineItemMetadataMap[cursorLineNum][2], "cancel", prevBufferNum)
			--After the cancel, refresh the view
			vim.cmd('bd')
			habitView.renderHabitView()
		else
			print("To check an item, place your cursor to the agenda item and rerun this command.")
		end
	end, {})
end

return habitView
