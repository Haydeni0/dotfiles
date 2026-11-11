local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  -- Bootstrap at the commit lazy-lock.json pins, not the moving stable branch.
  local lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json'
  local commit = vim.json.decode(table.concat(vim.fn.readfile(lockfile), '\n'))['lazy.nvim'].commit
  for _, cmd in ipairs({
    { 'git', 'clone', '--filter=blob:none', 'https://github.com/folke/lazy.nvim.git', lazypath },
    { 'git', '-C', lazypath, 'checkout', '--quiet', commit },
  }) do
    local out = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
      error(('lazy.nvim bootstrap failed: %s\n%s'):format(table.concat(cmd, ' '), out))
    end
  end
end
vim.opt.rtp:prepend(lazypath)
require('lazy').setup('plugins')  -- load every file in lua/plugins/
