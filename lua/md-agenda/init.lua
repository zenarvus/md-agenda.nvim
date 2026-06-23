local vim = vim

local function setup(opts)
	local config = require("md-agenda.config").initConfig(opts)

	local common = require("md-agenda.common")
	local color = require("md-agenda.color")

	local insertDate = require("md-agenda.insertDate")
	local checkTask = require("md-agenda.checkTask")
	local updateProgress = require("md-agenda.updateProgress")
	local agendaView = require("md-agenda.agendaView")
	local habitView = require("md-agenda.habitView")
	local agendaDashboard = require("md-agenda.agendaDashboard")

	--Date Picker
	vim.api.nvim_create_user_command('TaskScheduled', function()
		local currentBufNum = vim.api.nvim_get_current_buf()
		insertDate.dateSelector(vim.api.nvim_buf_get_name(0),"scheduled",currentBufNum)
	end, {})
	vim.api.nvim_create_user_command('TaskDeadline', function()
		local currentBufNum = vim.api.nvim_get_current_buf()
		insertDate.dateSelector(vim.api.nvim_buf_get_name(0),"deadline",currentBufNum)
	end, {})

	--Agenda View
	vim.api.nvim_create_user_command('AgendaView',agendaView.agendaView, {})
	vim.api.nvim_create_user_command('AgendaViewWTF', function(avOpts)agendaView.agendaViewWTF(avOpts)end, {nargs = '*'})

	--Habit View
	vim.api.nvim_create_user_command('HabitView', habitView.renderHabitView, {})

	--Agenda Dashboard
	vim.api.nvim_create_user_command('AgendaDashboard', agendaDashboard.renderAgendaDashboard, {})

	--Clear all highlight for all files
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "*",
		callback = function()
			for _,m in ipairs(vim.fn.getmatches()) do
				if m.group == "todoType" or
				m.group == "habitType" or
				m.group == "doneType" or
				m.group == "dueType" or
				m.group == "infoType" or
				m.group == "cancelledTask" or
				m.group == "tag" or common.isTodoItem(m.group) then
					vim.fn.matchdelete(m.id)
				end
			end
		end,
	})

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "markdown",
		callback = function()

			-- Save user's original foldmethod setting
			local userFoldMethod = vim.o.foldmethod

			-- Apply custom folding based on user's existing foldmethod
			if userFoldMethod == "expr" then
				vim.opt_local.foldexpr = 'v:lua.require("md-agenda.common").fold_details()'
			elseif userFoldMethod == "syntax" then
				-- Add syntax-based folding for logbook sections without overriding existing syntax
				vim.cmd([[syntax region logbookFold start="<details logbook>" end="</details>" transparent fold keepend containedin=ALL]])
				vim.cmd('syntax sync fromstart')
			end
			-- Keep original marker-based folding, no changes needed
			-- Keep original indent folding, no changes needed

			--Check Task -- (Modify the current buffer and the current line in markdown documents. This changes in the view buffers.)
			vim.api.nvim_buf_create_user_command(0, 'CheckTask', function()
				local currentBufNum = vim.api.nvim_get_current_buf()
				checkTask.taskAction(vim.api.nvim_buf_get_name(0), vim.api.nvim_win_get_cursor(0)[1], "check", currentBufNum)
			end, {})
			vim.api.nvim_buf_create_user_command(0, 'CancelTask', function()
				local currentBufNum = vim.api.nvim_get_current_buf()
				checkTask.taskAction(vim.api.nvim_buf_get_name(0), vim.api.nvim_win_get_cursor(0)[1], "cancel", currentBufNum)
			end, {})

			--Update Progress--
			vim.api.nvim_buf_create_user_command(0, 'UpdateProgress', function()
				local progressCount = vim.fn.input("New Progress: ")
				if #progressCount == 0 then
					print("No change")
					return
				elseif not tonumber(progressCount) then
					print("Invalid progress count")
					return
				end
				local currentBufNum = vim.api.nvim_get_current_buf()
				updateProgress.updateTaskProgress(vim.api.nvim_buf_get_name(0), vim.api.nvim_win_get_cursor(0)[1], tonumber(progressCount), currentBufNum)
			end, {})

			--Re-highlight for the markdown files
			color.set_highlight("todoType", config.config.todoTypeColor, config.config.todoTypeColorBg)
			vim.cmd("call matchadd('todoType', 'TODO')")

			color.set_highlight("habitType", config.config.habitTypeColor, config.config.habitTypeColorBg)
			vim.cmd("call matchadd('habitType','HABIT')")

			color.set_highlight("dueType", config.config.dueTypeColor, config.config.dueTypeColorBg)
			vim.cmd("call matchadd('dueType','DUE')")

			color.set_highlight("doneType", config.config.doneTypeColor, config.config.doneTypeColorBg)
			vim.cmd("call matchadd('doneType','DONE')")

			color.set_highlight("infoType", config.config.infoTypeColor, config.config.infoTypeColorBg)
			vim.cmd("call matchadd('infoType','INFO')")

			color.set_highlight("cancelledTask", config.config.cancelledTypeColor, config.config.cancelledTypeColorBg)
			vim.cmd("call matchadd('cancelledTask','CANCELLED')")

			color.set_highlight("tag", config.config.tagColor, config.config.tagColorBg)
			vim.cmd("call matchadd('tag','\\#[a-zA-Z0-9]\\+')")
			vim.cmd("call matchadd('tag',':[a-zA-Z0-9:]\\+:')")

			for customType, itsColor in pairs(config.config.customTodoTypes) do
				color.set_highlight(customType, itsColor)
				vim.cmd("call matchadd('"..customType.."', '"..customType.."')")
			end
		end,
	})

end

return {setup = setup}
