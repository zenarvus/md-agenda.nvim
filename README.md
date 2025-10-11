# md-agenda.nvim
![GitHub stars](https://img.shields.io/github/stars/zenarvus/md-agenda.nvim?style=flat-square)
![Forks](https://img.shields.io/github/forks/zenarvus/md-agenda.nvim?style=flat-square)
![Issues](https://img.shields.io/github/issues/zenarvus/md-agenda.nvim?style=flat-square)
![License](https://img.shields.io/badge/license-GPL%20v3-blue.svg?style=flat-square)

A Markdown time and task management plugin for NeoVim, inspired by org-agenda.

> [!IMPORTANT]
> **For the full documentation and syntax guide, please refer [here](https://github.com/zenarvus/md-agenda.nvim/wiki)**

## Showcase
![md-agenda-agenda.png](https://zenarvus.com/media/content/md-agenda-agenda.png)

![md-agenda-habits.png](https://zenarvus.com/media/content/md-agenda-habits.png)

## Installation/Configuration
**This plugin requires [ripgrep](https://github.com/BurntSushi/ripgrep) to work!**

### Using lazy.nvim
```lua
{"zenarvus/md-agenda.nvim",
    config = function ()
        require("md-agenda").setup({
            --- REQUIRED ---
            agendaFiles = {
                "~/notes/agenda.md", "~/notes/habits.md", -- Single Files
                "~/notes/agendafiles/", -- Folders
            },

            --- OPTIONAL ---
            -- Number of days to display on one agenda view page. 
            -- Default: 10
            agendaViewPageItems=10,
            -- Number of days before the deadline to show a reminder for the task in the agenda view.
            -- Default: 30
            remindDeadlineInDays=30,
            -- Number of days before the scheduled time to show a reminder for the task in the agenda view. 
            -- Default: 10
            remindScheduledInDays=10,
            -- "vertical" or "horizontal"
            -- Default: "horizontal"
            agendaViewSplitOrientation="horizontal",

            -----
            
            -- Number of past days to show in the habit view.
            -- Default: 24
            habitViewPastItems=24,
            -- Number of future days to show in the habit view.
            -- Default: 3
            habitViewFutureItems=3,
            -- "vertical" or "horizontal"
            -- Default: "horizontal"
            habitViewSplitOrientation="horizontal",

            -- Custom types that you can use instead of TODO.
            -- Default: {}
            -- The plugin will give an error if you use RGB colors (e.g. #ffffff)
            customTodoTypes={SOMEDAY="magenta"}, -- A map of item type and its color

            -- "vertical" or "horizontal"
            -- Default: "horizontal"
            dashboardSplitOrientation="horizontal",
            -- Set the dashboard view.
            dashboard = {
                {"All TODO Items", -- Group name
                    {
                        -- Item types, e.g., {"TODO", "INFO"}.
                        -- Gets the items that match one of the given types. Ignored if empty.
                        type={"TODO"},

                        -- List of tags to filter. Use AND/OR conditions.
                        -- e.g., {AND = {"tag1", "tag2"}, OR = {"tag1", "tag2"}}. Ignored if empty.
                        tags={},

                        -- Both, deadline and scheduled filters can take the same parameters.
                        -- "none", "today", "past", "nearFuture", "before-yyyy-mm-dd", "after-yyyy-mm-dd".
                        -- Ignored if empty.
                        deadline="",
                        scheduled="",
                    },
                    -- {...}, Additional filter maps can be added in the same group.
                },
                -- {"Other Group", {...}, ...}
                -- ...
            },

            -- Optional: Change agenda colors.
            tagColor = "blue",
            titleColor = "yellow",

            todoTypeColor = "cyan",
            habitTypeColor = "cyan",
            infoTypeColor = "lightgreen",
            dueTypeColor = "red",
            doneTypeColor = "green",
            cancelledTypeColor = "red",

            completionColor = "lightgreen",
            scheduledTimeColor = "cyan",
            deadlineTimeColor = "red",

            habitScheduledColor = "yellow",
            habitDoneColor = "green",
            habitProgressColor = "lightgreen",
            habitPastScheduledColor = "darkyellow",
            habitFreeTimeColor = "blue",
            habitNotDoneColor = "red",
            habitDeadlineColor = "gray",
        })

        -- Optional: Set keymaps for commands
        vim.keymap.set('n', '<A-t>', ":CheckTask<CR>")
        vim.keymap.set('n', '<A-c>', ":CancelTask<CR>")

        vim.keymap.set('n', '<A-h>', ":HabitView<CR>")
        vim.keymap.set('n', '<A-o>', ":AgendaDashboard<CR>")
        vim.keymap.set('n', '<A-a>', ":AgendaView<CR>")

        vim.keymap.set('n', '<A-s>', ":TaskScheduled<CR>")
        vim.keymap.set('n', '<A-d>', ":TaskDeadline<CR>")

        -- Optional: Set a foldmethod to use when folding the logbook entries.
        -- The plugin tries to respect to the user default.
        vim.o.foldmethod = "marker" -- "marker", "syntax" or "expr"
        -- Note: When navigating to the buffers with Telescope, "syntax" and "expr" options may not work properly.

        -- Optional: Create a custom agenda view command to only show the tasks with specific tags
        vim.api.nvim_create_user_command("WorkAgenda", function()
            vim.cmd("AgendaViewWTF work companyA") -- Run the agenda view with tag filters
        end, {})
    end
},
```
