local config = {}

config.config = {}

config.initConfig = function(opts)
	config.config.agendaFiles = opts.agendaFiles or {}
	config.config.agendaViewPageItems = opts.agendaViewPageItems or 10
	config.config.agendaViewSplitOrientation = opts.agendaViewSplitOrientation or "horizontal"

	config.config.remindDeadlineInDays = opts.remindDeadlineInDays or 30
	config.config.remindScheduledInDays = opts.remindScheduledInDays or 10

	config.config.habitViewPastItems = opts.habitViewPastItems or 24
	config.config.habitViewFutureItems = opts.habitViewFutureItems or 3
	config.config.habitViewSplitOrientation = opts.habitViewSplitOrientation or "horizontal"
	config.config.foldmarker = opts.folmarker or "{{{,}}}"

	config.config.customTodoTypes = opts.customTodoTypes or {}

	config.config.dashboardSplitOrientation = opts.dashboardSplitOrientation or "horizontal"

	config.config.dashboard = opts.dashboard or {
		{"All TODO Items",
			{
				type={"TODO"},
				tags={},
				deadline="",
				scheduled="",
			},
		},
	}

	config.config.tagColor = opts.tagColor or "gray"
	config.config.titleColor = opts.titleColor or "yellow"

	config.config.todoTypeColor = opts.todoTypeColor or "cyan"
	config.config.habitTypeColor = opts.habitTypeColor or "lightblue"
	config.config.infoTypeColor = opts.infoTypeColor or "lightgreen"
	config.config.dueTypeColor = opts.dueTypeColor or "red"
	config.config.doneTypeColor = opts.doneTypeColor or "green"
	config.config.cancelledTypeColor = opts.cancelledTypeColor or "red"

	config.config.completionColor = opts.completionColor or "lightgreen"

	config.config.scheduledTimeColor = opts.scheduledTimeColor or "cyan"
	config.config.deadlineTimeColor = opts.deadlineTimeColor or "red"

	config.config.habitScheduledColor = opts.habitScheduledColor or "yellow"
	config.config.habitDoneColor = opts.habitDoneColor or "green"
	config.config.habitProgressColor = opts.habitProgressColor or "lightgreen"
	config.config.habitPastScheduledColor = opts.habitPastScheduledColor or "darkyellow"
	config.config.habitFreeTimeColor = opts.habitFreeTimeColor or "blue"
	config.config.habitNotDoneColor = opts.habitNotDoneColor or "red"
	config.config.habitDeadlineColor = opts.habitDeadlineColor or "gray"

	return config
end

return config
