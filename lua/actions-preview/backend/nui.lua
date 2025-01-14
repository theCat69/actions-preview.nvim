local M = {}

local job_is_running = function(job_id)
  return vim.fn.jobwait({ job_id }, 0)[1] == -1
end

function M.is_supported()
  local ok, _ = pcall(require, "nui.menu")
  return ok
end

function M.select(config, actions)
  local Layout = require("nui.layout")
  local Menu = require("nui.menu")
  local Popup = require("nui.popup")

  local create_popup = function()
    return Popup(vim.tbl_deep_extend("force", config.preview, {
      size = nil,
      border = {
        text = {
          top = "Code Action Preview",
        },
      },
    }))
  end
  local create_layout_box = function(popup, select)
    return Layout.Box({
      Layout.Box(popup, { size = config.preview.size }),
      Layout.Box(select, { size = config.select.size }),
    }, { dir = config.dir })
  end

  local term_ids = {}

  local nui_preview_blank = create_popup()
  local nui_popups = {}
  local nui_select
  local nui_layout

  nui_select = Menu(
    vim.tbl_deep_extend("force", config.select, {
      position = 0,
      size = nil,
      border = {
        text = {
          top = "Code Actions",
        },
      },
    }),
    {
      lines = vim.tbl_map(function(action)
        return Menu.item(action:title(), { action = action })
      end, actions),
      keymap = config.keymap,
      on_change = function(item)
        local popup = nui_popups[item.index]
        if not popup then
          popup = create_popup()
          nui_popups[item] = popup
        end

        nui_layout:update(create_layout_box(popup, nui_select))

        item.action:preview(function(preview)
          if popup.bufnr == nil then
            return
          end

          if preview and preview.cmdline then
            if not term_ids[popup.bufnr] then
              vim.api.nvim_buf_call(popup.bufnr, function()
                term_ids[popup.bufnr] = vim.fn.termopen(preview.cmdline)
              end)
            end
          else
            preview = preview or { syntax = "", text = "preview not available" }

            vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, vim.split(preview.text, "\n", true))
            vim.api.nvim_buf_set_option(popup.bufnr, "syntax", preview.syntax)
            vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", false)
          end
        end)
      end,
      on_submit = function(item)
        item.action:apply()
      end,
      on_close = function()
        for _, term_id in pairs(term_ids) do
          if job_is_running(term_id) then
            vim.fn.jobstop(term_id)
          end
        end

        nui_preview_blank:unmount()
        for _, popup in ipairs(nui_popups) do
          popup:unmount()
        end
        nui_select:unmount()
      end,
    }
  )

  nui_layout = Layout(config.layout, create_layout_box(nui_preview_blank, nui_select))
  nui_layout:mount()
end

return M
