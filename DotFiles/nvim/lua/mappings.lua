require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "<leader>ca", function()
  vim.lsp.buf.code_action()
end, {desc= "LSP Code Action"})


map("n", "<leader>lc", function()
  local lines = {}
  table.insert(lines, "\\begin{columns}[T]")
  table.insert(lines, "\\column{0.48\\textwidth}")
  table.insert(lines, "")
  table.insert(lines, "")
  table.insert(lines, "\\column{0.48\\textwidth}")
  table.insert(lines, "") 
  table.insert(lines, "\\end{columns}")
  local line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0,line,line,true,lines)
end, {desc = "Insert Latex Column"})


map("n", "<leader>lf", function()
  local lines = {}
  table.insert(lines, "\\begin{frame}[fragile]{TODO: TITLE}")
  table.insert(lines, "") 
  table.insert(lines, "") 
  table.insert(lines, "\\end{frame}")
  local line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0,line,line,true,lines)
end, {desc = "Insert Latex Frame"})


map("n", "<leader>lg", function()
  local lines = {}
  table.insert(lines, "\\includegraphics[width=1.0\\linewidth]{TODO.png}")
  local line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0,line,line,true,lines)
end, {desc = "Insert L"})


map("n", "<leader>sm", function()
  local lines = {}
  table.insert(lines, "module X #(")
  table.insert(lines, "")
  table.insert(lines, ")(") 
  table.insert(lines, "")
  table.insert(lines, ");")
  table.insert(lines, "")
  table.insert(lines, "endmodule")
  local line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0,line,line,true,lines)
end, {desc = "Insert Module prefab"})


map("n", "<leader>si", function()
  local lines = {}
  table.insert(lines, "`ifdef X")
  table.insert(lines, "`else")
  table.insert(lines, "`endif")
  local line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0,line,line,true,lines)
end, {desc = "Insert Ifdef prefab"})


map("n", "<leader>jp", function()
  local filepath = vim.fn.expand("%:p")
  local filename = vim.fn.expand("%:t:r")

  local _, finish = filepath:find("src/main/java")
  if not finish then
    _, finish = filepath:find("src/main/")
  end

  local package_name = ""
  if finish then
    local relative_path = filepath:sub(finish + 1)
    local dir_path = relative_path:match("(.+)/[^/]+$")
    if dir_path then
      package_name = dir_path:gsub("/",".")
    end
  end
  
  local lines = {}
  if package_name ~= "" then
    table.insert(lines, "package " .. package_name:sub(2) .. ";")
    table.insert(lines, "")
  end

  table.insert(lines, "public class " .. filename .." {")
  table.insert(lines, "")
  table.insert(lines, "}")

  vim.api.nvim_buf_set_lines(0,0,-1,false,lines)
end, {desc = "Insert Java package and class name"})

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
