-- Alpha dashboard: builds the base theme table itself via
-- alpha.themes.dashboard (the module returns the table directly), then
-- applies our branding/header + Snacks picker buttons.
-- Requires the `ui.alpha` + `editor.snacks_picker` extras in lazyvim.json:
-- snacks_picker's alpha integration calls dashboard.button, which only
-- exists once a base theme is present.
return {
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    opts = function()
      local dashboard = require("alpha.themes.dashboard")
      local branding_path = vim.fn.expand("~/.config/branding")
      local header = { "  OLADELE USMAN", "  codetesla51" }
      if vim.fn.filereadable(branding_path) == 1 then
        local lines = vim.fn.readfile(branding_path)
        while #lines > 0 and lines[#lines]:match("^%s*$") do table.remove(lines) end
        while #lines > 0 and lines[1]:match("^%s*$") do table.remove(lines, 1) end
        if #lines > 0 then
          header = lines
        end
      end
      dashboard.section.header.val = header
      dashboard.section.header.opts = { hl = "Title", position = "center" }
      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find File", "<cmd>lua Snacks.picker.files()<cr>"),
        dashboard.button("n", "  New File", ":ene <BAR> startinsert <CR>"),
        dashboard.button("r", "  Recent Files", "<cmd>lua Snacks.picker.recent()<cr>"),
        dashboard.button("g", "  Find Text", "<cmd>lua Snacks.picker.grep()<cr>"),
        dashboard.button("p", "  Projects", "<cmd>lua Snacks.picker.projects()<cr>"),
        dashboard.button("c", "  Config", "<cmd>lua Snacks.picker.files({ cwd = vim.fn.stdpath('config') })<cr>"),
        dashboard.button("q", "  Quit", ":qa<CR>"),
      }
      dashboard.section.footer.val = ""
      dashboard.opts.opts.noautocmd = true
      return dashboard
    end,
    config = function(_, dashboard)
      require("alpha").setup(dashboard.opts)
    end,
  },
}
