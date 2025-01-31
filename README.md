# md-agenda.nvim
Org-Agenda like, Markdown time and task management plugin for NeoVim.

## Installation
### Requirements
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

### Using lazy.nvim
```lua
{"zenarvus/md-agenda.nvim",
    config = function ()
        require("md-agenda").setup({
            agendaFiles = {"~/notes/agenda.md", "~/notes/habits.md"} --required, set the location of agenda files

            --optional
            agendaViewPageItems=10 --How many days should be in one agenda view page? - default: 10
            remindDeadlineInDays=30 --In how many days before the deadline, a reminder for the task should be shown today - default: 30
            habitViewPastItems=24 --How many past days should be in the habit view? - default: 24
            habitViewFutureItems=3 --How many future days should be in the habit view? -default: 3
            foldmarker="{{{,}}}" --For folding logbook entries -default: {{{,}}}
        })

        --optional: set keymaps for commands
        vim.keymap.set('n', '<A-t>', ":CheckTask<CR>")

        vim.keymap.set('n', '<A-h>', ":HabitView<CR>")
        vim.keymap.set('n', '<A-a>', ":AgendaView<CR>")
        vim.keymap.set('n', '<A-Left>', ":PrevAgendaPage<CR>")
        vim.keymap.set('n', '<A-Right>', ":NextAgendaPage<CR>")

        vim.keymap.set('n', '<A-s>', ":TaskScheduled<CR>")
        vim.keymap.set('n', '<A-d>', ":TaskDeadline<CR>")
    end
},
```

## Roadmap
- Support for different calendars (low priority)
- Support for remote markdown files in the views. A good way to show holidays and important events. (high priority)
- Using regexp for folding instead of markers. (medium priority)
- Showing tasks' completion times in the agenda view. (high priority)
- Redesigning the habit and agenda views. (high priority)

## Troubleshooting
Currently, I only fix the bugs I encounter and do not test the every case. If you find a bug, please open an issue.

---

## Agenda Item Structure
Here are some example tasks:
```md
# TODO: Learn to tie your shoes

# TODO: Mid-term exams
- Deadline: `2025-02-15 00:00`
- Scheduled: `2025-02-06 00:00`

# DONE: Refresh the fridge
- Completion: `2025-02-01 00:13`

# HABIT: Read a book (17/30)
- Last Completion: `2025-01-30 16:58`
- Scheduled: `2025-01-31 00:00 +1d`
<details logbook><!--{{{-->

 - [x] `2025-01-30 16:58` `(36/30)`
 - [x] `2025-01-29 14:28` `(32/30)`
 - [x] `2025-01-28 13:42` `(30/30)`
 - [x] `2025-01-27 17:53` `(30/30)`
 - [ ] `2025-01-24 13:27` `(28/30)`
 - [ ] `2025-01-23 12:54` `(23/30)`
<!--}}}--></details>

# INFO: International Workers' Day
- Scheduled: `2025-05-01 00:00 +1y`
```
### Agenda Item Types
This plugin considers markdown headers that starts with these strings as agenda items:
- "TODO:", "HABIT:", "INFO:", "DONE:", "DUE:"

**TODO:**\
Regular task item. You should do that.
- Can hold "Deadline" and "Scheduled" properties.
- Can be a repeating task.

**HABIT:**\
An agenda item for habit tracking.
- Only shown in the habit view.
- It must contain a repeating "Scheduled" property.

**INFO:**\
Only for viewing in the agenda view. Useful for holidays, anniversaries etc.
- It must contain a repeating "Scheduled" property.
- It should contain a "Deadline" property if, for example, holiday is spread to multiple days.

**DONE:**\
If a task item is completed before the deadline, it is marked as done.
- For repeating tasks, if the next scheduled time is going to exceed the given deadline, the task is marked as done.

**DUE:**\
If a task item is completed after the deadline, it is marked as due.
- For repeating tasks, if the current scheduled time exceeds the given deadline, the task is marked as due.

### Repeating Tasks
To make a task repeating, you should add the repeat indicator at the end of the "Deadline" or "Scheduled" property.
- You cannot add the repeat indicator to both of them at the same task.

**Repeat Indicator Types**:
- "+": Shifts the date to, for example one month (+1m) after the scheduled time or deadline. It can be still in the past and overdue even after marking it.
- "++": Shifts the date by for example at least one week (++1d) from scheduled time or deadline, but also by as many weeks as it takes to get this date into the future.
- ".+": Shifts the date to, for example one month (.+1m) after today.

**Repeat Indicator Intervals**:
- "d": n day after.
- "w": n Week after, same weekday.
- "m": n Month after, same day of the month.
- "y": n Year after, same month and day of the month.

## Checking a Task
To check a task, place cursor to it and use `:CheckTask` command.

Tasks cannot be checked when:
- The task is malformed
- Scheduled time did not arrive
- The task is DONE, DUE or INFO
- Repeating task has a progress indicator with a zero progress

If the task is a repeating task, the completed task is directly saved to the logbook without any change in the task type.

## Agenda View
Use `:AgendaView` command to open agenda view. To switch between pages, use `:PrevAgendaPage` and `:NextAgendaPage`. (Pages are relative to today)

- If the task has a scheduled time but no deadline time, it is shown on the scheduled day. Also, it is shown today until finished.
- If the task has a deadline time but no scheduled time, it is shown on the deadline day. Also, based on the configuration, if today is close to the deadline, it's shown today.
- If the task has both a deadline and scheduled time, it is shown in both the deadline and scheduled time. Also, if today is between these times, it is shown today.
- If the task is a repeating task, it is shown in the scheduled time and the next days based on the repeat indicator until the deadline.
- If the task has no deadline nor scheduled time, it is shown today.

## Habit View
To open the habit view, use `:HabitView` command. Only habit tasks shown in the habit view.

**Colors**
- Yellow: If the task is scheduled on that time.
- Blue: If you do not have to do the task on that time.
- Green: If the task is done on that day.
- Light Green: If progress had been made but the task was not done.
- If the habit is scheduled in the past but has not been made
  + Today is shown in yellow
  + That past scheduled day is shown in dark yellow
- Red: If task had to be done that day but it was not.
- Gray: If the deadline on that time.

## Date Selection
To insert a deadline or scheduled time, place cursor to the task and use one of the `:TaskDeadline` or `:TaskScheduled` commands.\
Telescope will list date items starting from today to next 364 days.
