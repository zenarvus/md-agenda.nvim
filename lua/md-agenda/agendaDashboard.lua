local config = require("md-agenda.config")

local common = require("md-agenda.common")

local taskAction = require("md-agenda.checkTask")
local updateProgress = require("md-agenda.updateProgress")

local vim = vim

local agendaDashboard = {}

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

local function passesFilters(group,agendaItem)
	--for _,groupFilter in ipairs(group) do
	for i = 1, #group do
		local groupFilter = group[i]
		-- the first value of groupFilter is the groupName
		-- So, we need to skip it.
		if i==1 then goto continue end

		-- The rest of the values are maps that contain filters

		--Check if the agenda item passes type filter.
		local typeFilterPass=true
		if groupFilter.type and #groupFilter.type > 0 then
			local typeMatch = false
			for _,filterItemType in ipairs(groupFilter.type) do
				if agendaItem.agendaItem[1] == filterItemType then
					typeMatch = true
					break
				end
			end
			typeFilterPass = typeMatch
		end

		--Check if the agenda item passes tag filter.
		local tagFilterPass=true
		if groupFilter.tags then
			--AND filter passing
			local tagFilterANDPass=true
			if groupFilter.tags["AND"] and #groupFilter.tags["AND"] > 0 then
				tagFilterANDPass=false

				local tagANDmatchCount = 0
				for _,andTag in ipairs(groupFilter.tags["AND"]) do
					if agendaItem.agendaItem[2]:match("#"..andTag) or agendaItem.agendaItem[2]:match(":"..andTag..":") then
						tagANDmatchCount = tagANDmatchCount + 1
					end
				end

				if tagANDmatchCount == #groupFilter.tags["AND"] then
					tagFilterANDPass = true
				end
			end

			--OR filter passing
			local tagFilterORPass=true
			if groupFilter.tags["OR"] and #groupFilter.tags["OR"] > 0 then
				tagFilterORPass=false
				for _,orTag in ipairs(groupFilter.tags["OR"]) do
					if agendaItem.agendaItem[2]:match("#"..orTag) or agendaItem.agendaItem[2]:match(":"..orTag..":") then
						tagFilterORPass=true
						break
					end
				end

			end

			tagFilterPass = (tagFilterANDPass and tagFilterORPass)
		end

		--Check if the agenda item passes deadline filter.
		local deadlineFilterPass=true
		if groupFilter.deadline and #groupFilter.deadline > 0 then
			if agendaItem.properties["Deadline"] then
				local currentTime = os.time()
				local currentTimeTable = os.date("*t",currentTime)
				local dyear, dmonth, dday = agendaItem.properties["Deadline"]:match("([0-9]+)%-([0-9]+)%-([0-9]+)")
				local deadlineUnix = os.time({year=dyear, month=dmonth, day=dday})

				if groupFilter.deadline == "none" then
					deadlineFilterPass = false

				elseif groupFilter.deadline == "today" then
					if currentTimeTable.year == dyear and currentTimeTable.month == dmonth and currentTimeTable.day == dday then
						deadlineFilterPass = true

					else deadlineFilterPass = false end

				elseif groupFilter.deadline == "nearFuture" then
					--insert text to current date if the current date is close to task deadline by n days
					--also if current date is not higher than the task deadline originally
					if (currentTime < deadlineUnix) and
					(currentTime + ((config.config.remindDeadlineInDays+1)*common.oneDay) > deadlineUnix) then
						deadlineFilterPass = true

					else deadlineFilterPass = false end

				elseif groupFilter.deadline == "past" then
					if deadlineUnix < currentTime then
						deadlineFilterPass = true

					else deadlineFilterPass = false end

				elseif groupFilter.deadline:match("^before-[0-9]+%-[0-9]+%-[0-9]+") then
					local fyear, fmonth, fday = groupFilter.deadline:match("([0-9]+)%-([0-9]+)%-([0-9]+)")

					if deadlineUnix < os.time({year=fyear, month=fmonth, day=fday}) then
						deadlineFilterPass = true

					else deadlineFilterPass = false end

				elseif groupFilter.deadline:match("^after-[0-9]+%-[0-9]+%-[0-9]+") then
					local fyear, fmonth, fday = groupFilter.deadline:match("([0-9]+)%-([0-9]+)%-([0-9]+)")

					if os.time({year=fyear, month=fmonth, day=fday}) < deadlineUnix then
						deadlineFilterPass = true

					else deadlineFilterPass = false end
				end
			else
				if groupFilter.deadline ~= "none" then
					deadlineFilterPass=false
				end
			end
		end

		--Check if the agenda item passes scheduled filter
		local scheduledFilterPass=true
		if groupFilter.scheduled and #groupFilter.scheduled > 0 then
			if agendaItem.properties["Scheduled"] then
				local currentTime = os.time()
				local currentTimeTable = os.date("*t",currentTime)
				local syear, smonth, sday = agendaItem.properties["Scheduled"]:match("([0-9]+)%-([0-9]+)%-([0-9]+)")
				local scheduledUnix = os.time({year=syear, month=smonth, day=sday})

				if groupFilter.scheduled == "none" then
					scheduledFilterPass=false

				elseif groupFilter.scheduled == "today" then
					if currentTimeTable.year == syear and currentTimeTable.month == smonth and currentTimeTable.day == sday then
						scheduledFilterPass = true

					else scheduledFilterPass = false end

				elseif groupFilter.scheduled == "nearFuture" then
					if (currentTime < scheduledUnix) and
					(currentTime + ((config.config.remindScheduledInDays+1)*common.oneDay) > scheduledUnix) then
						scheduledFilterPass = true

					else scheduledFilterPass = false end

				elseif groupFilter.scheduled == "past" then
					if scheduledUnix < currentTime then
						scheduledFilterPass = true

					else scheduledFilterPass = false end

				elseif groupFilter.scheduled:match("^before-[0-9]+%-[0-9]+%-[0-9]+") then
					local fyear, fmonth, fday = groupFilter.deadline:match("([0-9]+)%-([0-9]+)%-([0-9]+)")

					if os.time({year=fyear, month=fmonth, day=fday}) < scheduledUnix then
						scheduledFilterPass = true

					else scheduledFilterPass = false end

				elseif groupFilter.scheduled:match("^after-[0-9]+%-[0-9]+%-[0-9]+") then
					local fyear, fmonth, fday = groupFilter.deadline:match("([0-9]+)%-([0-9]+)%-([0-9]+)")

					if scheduledUnix < os.time({year=fyear, month=fmonth, day=fday}) then
						scheduledFilterPass = true

					else scheduledFilterPass = false end
				end
			else
				if groupFilter.scheduled ~= "none" then
					scheduledFilterPass=false
				end
			end
		end

		if (typeFilterPass and tagFilterPass and deadlineFilterPass and scheduledFilterPass) == true then
			return true
		end
		::continue::
	end

	return false
end

local function getGroupsAndItems()
	local agendaItems = common.getAgendaItems("")

	local currentTime = os.time()
	local currentDateStr = os.date("%Y-%m-%d", currentTime)

	--[[{
		{groupName, {
			{filepath, linenum, itemText1},
			{filepath, linenum, itemText2},
			...
		}},
		...
	}]]
	local groupsAndItems = {}

	--[[if not config.config.dashboardOrder then
		print("No items in dashboard order.")
		return {}
	end]]

	--local noPass = 0

	for _,group in ipairs(config.config.dashboard) do
		local groupName = group[1]
		local groupAndItsItems = {groupName}

		local groupItems = {}

		for _, agendaItem in ipairs(agendaItems) do
			--if not passesFilters(groupName, agendaItem) then noPass = noPass + 1 end
			if passesFilters(group, agendaItem) then
				local itemText = ""

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

					--If the scheduled time is today
					local scheduledDate = agendaItem.properties["Scheduled"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
					if currentDateStr == scheduledDate then
						--if its info, do not show "Scheduled:" text
						if agendaItem.agendaItem[1]=="INFO" then
							itemText = showTimeStrInAgendaItem(agendaItem.properties["Scheduled"])..
							agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]
						else
							itemText = "Scheduled: "..showTimeStrInAgendaItem(agendaItem.properties["Scheduled"])..
							agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]
						end

					--If the scheduled time is in the past or in the future
					elseif (parsedScheduled["unixTime"] < currentTime) or (currentTime < parsedScheduled["unixTime"]) then
						itemText = agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
						" (SC: "..remainingOrPassedDays(currentDateStr, agendaItem.properties["Scheduled"])..")"
					end

				--If only Deadline exists
				elseif (not agendaItem.properties["Scheduled"]) and agendaItem.properties["Deadline"] then
					--If the deadline is today
					local deadlineDate = agendaItem.properties["Deadline"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
					if deadlineDate == currentDateStr then
						itemText = "Deadline: "..showTimeStrInAgendaItem(agendaItem.properties["Deadline"])..
						agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]

					--If the deadline is in the future or in the past
					elseif (currentTime < parsedDeadline["unixTime"]) or (parsedDeadline["unixTime"] < currentTime) then
						itemText = agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
						" (DL: "..remainingOrPassedDays(currentDateStr, agendaItem.properties["Deadline"])..")"
					end

				--If both Scheduled and Deadline do exist
				elseif agendaItem.properties["Scheduled"] and agendaItem.properties["Deadline"] then

					local scheduledDate=agendaItem.properties["Scheduled"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
					local deadlineDate=agendaItem.properties["Deadline"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
					--If the scheduled date is in the future
					if currentTime < parsedScheduled["unixTime"] then
						itemText = agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
						" (SC: "..remainingOrPassedDays(currentDateStr, agendaItem.properties["Scheduled"])..")"
					--If the scheduled date is today
					elseif currentDateStr == scheduledDate then
						itemText = "Scheduled: "..showTimeStrInAgendaItem(agendaItem.properties["Scheduled"])..
						agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
						" (DL: "..remainingOrPassedDays(scheduledDate, agendaItem.properties["Deadline"])..")"

					--If the deadline is in the future or is in the past
					elseif (currentTime < parsedDeadline["unixTime"]) or (parsedDeadline["unixTime"] < currentTime) then
						itemText = agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]..
						" (DL: "..remainingOrPassedDays(currentDateStr, agendaItem.properties["Deadline"])..")"
					--If the deadline is today
					elseif currentDateStr == deadlineDate then
						itemText = "Deadline: "..showTimeStrInAgendaItem(agendaItem.properties["Deadline"])..
						agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]
					end

				--If not Scheduled nor Deadline exists
				elseif (not agendaItem.properties["Scheduled"]) and (not agendaItem.properties["Deadline"]) then
					itemText = agendaItem.agendaItem[1].." "..agendaItem.agendaItem[2]
				end

				table.insert(groupItems, {agendaItem.metadata[1], agendaItem.metadata[2], itemText})
			end
		end

		table.insert(groupAndItsItems, groupItems)
		table.insert(groupsAndItems, groupAndItsItems)
	end

	--print("No Pass:", noPass, "Item Count:", #agendaItems)

	return groupsAndItems
end

agendaDashboard.renderAgendaDashboard = function()
	--To refresh the previous buffer's content. (The buffer that is focused before the view buffer)
	local prevBufferNum = vim.api.nvim_get_current_buf()

	if config.config.dashboardSplitOrientation == "vertical" then
		vim.cmd("vnew")
	else
		vim.cmd("new")
	end
	vim.cmd("set cursorline")

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

	local lineItemMetadataMap = {}

	local renderLines = {}

	local currentLine = 1
	table.insert(renderLines, "Agenda Dashboard")

	local groupsAndItems = getGroupsAndItems()

	for _, group in ipairs(groupsAndItems) do
		currentLine = currentLine + 1
		table.insert(renderLines, "- "..group[1])

		for _, item in ipairs(group[2]) do
			currentLine = currentLine + 1
			lineItemMetadataMap[currentLine]={item[1], item[2]}
			table.insert(renderLines, "  "..item[3])
		end
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
			agendaDashboard.renderAgendaDashboard()
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
			agendaDashboard.renderAgendaDashboard()
			vim.cmd(tostring(cursorLineNum))
		else
			print("To check an item, place your cursor to the agenda item and rerun this command.")
		end
	end, {})
	--Task cancel command
	vim.api.nvim_buf_create_user_command(0, 'CancelTask', function()
		local cursorLineNum = vim.api.nvim_win_get_cursor(0)[1]
		if lineItemMetadataMap[cursorLineNum] then
			taskAction.taskAction(lineItemMetadataMap[cursorLineNum][1], lineItemMetadataMap[cursorLineNum][2], "cancel", prevBufferNum)
			--After the cancel, refresh the view
			vim.cmd('bd')
			agendaDashboard.renderAgendaDashboard()
			vim.cmd(tostring(cursorLineNum))
		else
			print("To check an item, place your cursor to the agenda item and rerun this command.")
		end
	end, {})
end

return agendaDashboard
