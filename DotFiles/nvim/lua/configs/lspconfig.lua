-- Configure jdtls with explicit command pointing to Mason's installed binary
vim.lsp.config("jdtls", {
  cmd = { "jdtls" },
  settings = {
    java = {
      configuration = {
        runtimes = {
          {
            name = "JavaSE-25",
            path = "/usr/lib/jvm/default",
          },
        },
      },
    },
  },
})

-- Enable your language servers safely
vim.lsp.enable("jdtls")
vim.lsp.enable("html")
vim.lsp.enable("cssls")
vim.lsp.enable("ts_ls")
vim.lsp.enable("verible")
