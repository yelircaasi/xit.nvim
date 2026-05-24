get_resolved_highlight_by_id = function(id)
  local result = {}
  local main_highlight = vim.api.nvim_get_hl_by_id(id, true)

  if main_highlight[true] then
    local linked_id = main_highlight[true]
    local linked_highlight = get_resolved_highlight_by_id(linked_id)

    for key, value in pairs(linked_highlight) do
      result[key] = value
    end

    main_highlight[true] = nil
  end

  for key, value in pairs(main_highlight) do
    result[key] = value
  end

  return result
end

local get_resolved_highlight_by_name = function(name)
  return get_resolved_highlight_by_id(vim.api.nvim_get_hl_id_by_name(name))
end

local set_highlighting = function()
  local headlineHighlight = get_resolved_highlight_by_name('Title')
  local openHighlight = get_resolved_highlight_by_name('Normal')
  local openCheckboxHighlight = get_resolved_highlight_by_name('ErrorMsg')
  local ongoingHighlight = get_resolved_highlight_by_name('WarningMsg')
  local checkedHighlight = get_resolved_highlight_by_name('Comment')
  local obsoleteHighlight = get_resolved_highlight_by_name('NonText')
  local obsoleteStrikedHighlight = get_resolved_highlight_by_name('Comment')
  local priorityHighlight = get_resolved_highlight_by_name('WarningMsg')
  local inquestionHighlight = get_resolved_highlight_by_name('SpecialChar')

  headlineHighlight.bg = nil
  openHighlight.bg = nil
  openCheckboxHighlight.bg = nil
  ongoingHighlight.bg = nil
  checkedHighlight.bg = nil
  obsoleteHighlight.bg = nil
  obsoleteStrikedHighlight.bg = nil
  priorityHighlight.bg = nil
  inquestionHighlight.bg = nil

  headlineHighlight.underline = true
  headlineHighlight.bold = true
  openCheckboxHighlight.bold = true
  openHighlight.bold = nil
  ongoingHighlight.bold = true
  priorityHighlight.bold = true
  checkedHighlight.italic = nil
  checkedHighlight.bold = nil
  obsoleteHighlight.italic = nil
  obsoleteHighlight.bold = nil
  obsoleteStrikedHighlight.italic = nil
  obsoleteStrikedHighlight.strikethrough = true
  inquestionHighlight.strikethrough = nil

  local hi = function(name, opts)
    vim.api.nvim_set_hl(0, name, opts)
  end

  hi('@XitHeadline', headlineHighlight)

  hi('@XitOpenCheckbox', openCheckboxHighlight)
  hi('@XitOpenTaskMainLine', openHighlight)
  hi('@XitOpenTaskOtherLine', openHighlight)
  hi('@XitOpenTaskPriority', priorityHighlight)

  hi('@XitOngoingCheckbox', ongoingHighlight)
  hi('@XitOngoingTaskMainLine', ongoingHighlight)
  hi('@XitOngoingTaskOtherLine', ongoingHighlight)
  hi('@XitOngoingTaskPriority', priorityHighlight)

  hi('@XitCheckedCheckbox', checkedHighlight)
  hi('@XitCheckedTaskMainLine', checkedHighlight)
  hi('@XitCheckedTaskOtherLine', checkedHighlight)
  hi('@XitCheckedTaskPriority', checkedHighlight)

  hi('@XitObsoleteCheckbox', obsoleteHighlight)
  hi('@XitObsoleteTaskMainLine', obsoleteStrikedHighlight)
  hi('@XitObsoleteTaskOtherLine', obsoleteStrikedHighlight)
  hi('@XitObsoleteTaskPriority', obsoleteStrikedHighlight)

  hi('@XitInQuestionCheckbox', inquestionHighlight)
  hi('@XitInQuestionTaskMainLine', inquestionHighlight)
  hi('@XitInQuestionTaskOtherLine', inquestionHighlight)
  hi('@XitInQuestionTaskPriority', inquestionHighlight)
end

local set_mappings = function(M, augroup, options)
  local jump_between_all_tasks = { 'task' }
  local jump_between_open_and_ongoing_tasks = { 'open_task', 'ongoing_task' }
  local jump_between = options.default_jump_group == 'all' and jump_between_all_tasks
    or jump_between_open_and_ongoing_tasks

  local toggle_jumps = function()
    if jump_between == jump_between_all_tasks then
      jump_between = jump_between_open_and_ongoing_tasks
      print('Jumping toggled to open and ongoing tasks')
    else
      jump_between = jump_between_all_tasks
      print('Jumping toggled to all tasks')
    end
  end

  local names_interactions = {
    toggle_checkbox = function()
      M.toggle_checkbox(false)
    end,
    toggle_checkbox_reverse = function()
      M.toggle_checkbox(true)
    end,
    jump_to_next_task = function()
      M.jump_to_next_task(options.wrap_jumps, jump_between)
    end,
    jump_to_previous_task = function()
      M.jump_to_previous_task(options.wrap_jumps, jump_between)
    end,
    jump_to_next_headline = function()
      M.jump_to_next_headline(options.wrap_jumps)
    end,
    jump_to_previous_headline = function()
      M.jump_to_previous_headline(options.wrap_jumps)
    end,
    create_new_task_before = function()
      M.create_new_task(true)
    end,
    create_new_task_after = function()
      M.create_new_task(false)
    end,
    create_new_headline_before = function()
      M.create_new_headline(true)
    end,
    create_new_headline_after = function()
      M.create_new_headline(false)
    end,
    toggle_jumps = toggle_jumps,
    delete_task = M.delete_task,
    filter_open_ongoing_tasks = function()
      M.filter_tasks({ 'open_task', 'ongoing_task' })
    end,
    filter_checked_tasks = function()
      M.filter_tasks({ 'checked_task' })
    end,
  }

  vim.api.nvim_create_autocmd('FileType', {
    group = augroup,
    pattern = 'xit',
    callback = function()
      for key_strokes, interaction in pairs(options.keymaps or {}) do
        local f = names_interactions[interaction]
        if f ~= nil then
          vim.keymap.set('n', key_strokes, f, { buffer = true, silent = true })
        end
      end
    end,
  })
end

local get_node_for_cursor = function(cursor)
  if cursor == nil then
    return vim.treesitter.get_node()
  end
  return vim.treesitter.get_node({ pos = { cursor[1] - 1, cursor[2] } })
end

local get_node_of_type = function(type, cursor)
  local node = get_node_for_cursor(cursor)
  if node == nil then
    return nil
  end

  local root = get_root_for_node(node)

  while node ~= nil and node ~= root and node:type() ~= type do
    node = node:parent()
  end

  if node:type() == type then
    return node
  else
    return nil
  end
end

local get_node_of_types = function(types, cursor)
  for _, type in ipairs(types) do
    local node = get_node_of_type(type, cursor)
    if node ~= nil then
      return node
    end
  end
end

local get_checkbox = function(task_node)
  if task_node:type() == 'task' then
    return task_node:child():child()
  elseif
    task_node:type() == 'open_task'
    or task_node:type() == 'ongoing_task'
    or task_node:type() == 'checked_task'
    or task_node:type() == 'obsolete_task'
    or task_node:type() == 'in_question_task'
  then
    return task_node:child()
  else
    return nil
  end
end

local get_next_checkbox_status_char = function(checkbox_node, toogle_back)
  if checkbox_node:type() == 'open_checkbox' then
    return toogle_back and '~' or '@'
  elseif checkbox_node:type() == 'ongoing_checkbox' then
    return toogle_back and ' ' or 'x'
  elseif checkbox_node:type() == 'checked_checkbox' then
    return toogle_back and '@' or '~'
  elseif checkbox_node:type() == 'obsolete_checkbox' then
    return toogle_back and '~' or '?'
  else
    return toogle_back and '?' or ' '
  end
end

local find_next_task = function(current_task_node, start_line, end_line, types)
  types = types or { 'task' }

  for i = start_line, end_line do
    local next_task = get_node_of_types(types, { i, 0 })

    if
      next_task ~= nil
      and (current_task_node == nil or (next_task ~= current_task_node and next_task:parent() ~= current_task_node))
    then
      local checkbox_row = get_checkbox(next_task):range()
      vim.api.nvim_win_set_cursor(0, { checkbox_row + 1, 4 })
      return true
    end
  end

  return false
end

local find_previous_task = function(current_task_node, start_line, end_line, types)
  types = types or { 'task' }

  for i = start_line, end_line, -1 do
    local previous_task = get_node_of_types(types, { i, 0 })

    if
      previous_task ~= nil
      and (
        current_task_node == nil
        or (previous_task ~= current_task_node and previous_task:parent() ~= current_task_node)
      )
    then
      local checkbox_row = get_checkbox(previous_task):range()
      vim.api.nvim_win_set_cursor(0, { checkbox_row + 1, 4 })
      return true
    end
  end

  return false
end

local find_next_headline = function(current_headline_node, start_line, end_line)
  for i = start_line, end_line do
    local next_headline = get_node_of_type('headline', { i, 0 })

    if next_headline ~= nil and (current_headline_node == nil or next_headline ~= current_headline_node) then
      local headline_row = next_headline:range()
      vim.api.nvim_win_set_cursor(0, { headline_row + 1, 0 })
      return true
    end
  end

  return false
end

local find_previous_headline = function(current_headline_node, start_line, end_line)
  for i = start_line, end_line, -1 do
    local previous_headline = get_node_of_type('headline', { i, 0 })

    if previous_headline ~= nil and (current_headline_node == nil or previous_headline ~= current_headline_node) then
      local headline_row = previous_headline:range()
      vim.api.nvim_win_set_cursor(0, { headline_row + 1, 0 })
      return true
    end
  end

  return false
end

local insert_new_line = function()
  local key = vim.api.nvim_replace_termcodes('<CR>', true, false, true)
  vim.api.nvim_feedkeys(key, 'n', false)
end

local insert_new_indented_line = function()
  local key = vim.api.nvim_replace_termcodes('<CR><Tab>', true, false, true)
  vim.api.nvim_feedkeys(key, 'n', false)
end

--------------
--- COLORS ---
--------------

-----------------------
-- MODULE DEFINITION --
-----------------------

local M = {}

M.toggle_checkbox = function(toggle_back)
  local task_node = get_node_of_type('task')

  if task_node == nil then
    return
  end

  local checkbox_node = get_checkbox(task_node)
  local next_status = get_next_checkbox_status_char(checkbox_node, toggle_back)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = checkbox_node:range()

  vim.api.nvim_buf_set_text(bufnr, start_row, start_col + 1, end_row, end_col - 1, { next_status })
end

M.jump_to_next_task = function(wrap, types)
  local current_task_node = get_node_of_type('task')
  local cursor = vim.api.nvim_win_get_cursor(0)
  local max_line = vim.api.nvim_buf_line_count(0)
  local found = find_next_task(current_task_node, cursor[1], max_line, types)

  if wrap and not found then
    find_next_task(current_task_node, 0, cursor[1] - 1, types)
  end
end

M.jump_to_previous_task = function(wrap, types)
  local current_task_node = get_node_of_type('task')
  local cursor = vim.api.nvim_win_get_cursor(0)
  local found = find_previous_task(current_task_node, cursor[1], 0, types)

  if wrap and not found then
    local max_line = vim.api.nvim_buf_line_count(0)

    find_previous_task(current_task_node, max_line, cursor[1] + 1, types)
  end
end

M.jump_to_next_headline = function(wrap)
  local current_headline_node = get_node_of_type('headline')
  local cursor = vim.api.nvim_win_get_cursor(0)
  local max_line = vim.api.nvim_buf_line_count(0)
  local found = find_next_headline(current_headline_node, cursor[1], max_line)

  if wrap and not found then
    find_next_headline(current_headline_node, 0, cursor[1] - 1)
  end
end

M.jump_to_previous_headline = function(wrap)
  local current_headline_node = get_node_of_type('headline')
  local cursor = vim.api.nvim_win_get_cursor(0)
  local found = find_previous_headline(current_headline_node, cursor[1], 0)

  if wrap and not found then
    local max_line = vim.api.nvim_buf_line_count(0)

    find_previous_headline(current_headline_node, max_line, cursor[1] + 1)
  end
end

M.create_new_task = function(before_current_task, stay_in_current_mode)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_task_node = get_node_of_type('task')
  local insertion_row

  if current_task_node ~= nil then
    local start_row, _, end_row = current_task_node:range()

    if before_current_task then
      insertion_row = start_row
    else
      insertion_row = end_row + 1
    end
  else
    insertion_row = cursor[1] - (before_current_task and 1 or 0)
  end

  vim.api.nvim_buf_set_lines(0, insertion_row, insertion_row, false, { '[ ] ' })
  vim.api.nvim_win_set_cursor(0, { insertion_row + 1, 4 })
  if not stay_in_current_mode then
    vim.cmd('startinsert!')
  end
end

M.create_new_headline = function(before_current_task, stay_in_current_mode)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_task_node = get_node_of_type('task')
  local insertion_row

  if current_task_node ~= nil then
    local start_row, _, end_row = current_task_node:range()

    if before_current_task then
      insertion_row = start_row
    else
      insertion_row = end_row + 1
    end
  else
    insertion_row = cursor[1] - (before_current_task and 1 or 0)
  end

  vim.api.nvim_buf_set_lines(0, insertion_row, insertion_row, false, { '', '' })
  vim.api.nvim_win_set_cursor(0, { insertion_row + 2, 0 })
  if not stay_in_current_mode then
    vim.cmd('startinsert!')
  end
end

M.create_new_task_in_insert_mode = function()
  local current_column = vim.api.nvim_eval('col(".")')
  local last_column = vim.api.nvim_eval('col("$")')

  if current_column == 1 then
    insert_new_line()
  elseif current_column == last_column then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local current_node = get_node_of_type('headline') or get_node_of_type('task', { cursor[1], cursor[2] - 1 })
    local at_the_end_of_task = false

    if current_node and current_node:type() == 'task' then
      local _, _, end_row = current_node:range()
      at_the_end_of_task = end_row + 1 == cursor[1]
    end

    if
      current_node and ((current_node:type() == 'task' and at_the_end_of_task) or current_node:type() == 'headline')
    then
      M.create_new_task(false, true)
    else
      local other_line_node = get_node_of_type('other_line', { cursor[1], cursor[2] - 1 })

      if other_line_node == nil then
        insert_new_indented_line()
      else
        insert_new_line()
      end
    end
  else
    local current_node = get_node_of_type('task')
    local other_line_node = get_node_of_type('other_line')
    local indent_node = get_node_of_type('indent')

    if current_node and current_node:type() == 'task' and (other_line_node == nil or indent_node) then
      insert_new_indented_line()
    else
      insert_new_line()
    end
  end
end

M.create_indented_line_in_insert_mode = function()
  local current_column = vim.api.nvim_eval('col(".")')
  local last_column = vim.api.nvim_eval('col("$")')

  if current_column == last_column then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local insertion_row = cursor[1]

    vim.api.nvim_buf_set_lines(0, insertion_row, insertion_row, false, { '    ' })
    vim.api.nvim_win_set_cursor(0, { insertion_row + 1, 4 })
  else
    local current_node = get_node_of_type('task')
    local other_line_node = get_node_of_type('other_line')

    if current_node and current_node:type() == 'task' and other_line_node == nil then
      insert_new_indented_line()
    else
      insert_new_line()
    end
  end
end

M.delete_task = function()
  local current_task_node = get_node_of_type('task')

  if current_task_node ~= nil then
    local start_row, _, end_row = current_task_node:range()
    vim.api.nvim_buf_set_lines(0, start_row, end_row + 1, false, {})
  else
    print('No task found under the cursor')
  end
end

local function get_root_for_node(node)
  local parent = node:parent()
  while parent do
    node = parent
    parent = node:parent()
  end
  return node
end

M.filter_tasks = function(types)
  local root = get_root_for_node(get_node_for_cursor())
  local tasks_to_remove = {}

  if types == nil then
    types = { 'open_task', 'ongoing_task' }
  end

  -- 1. eliminate tasks
  for node in root:iter_children() do
    if node:type() == 'task' then
      local task_type = node:child():type()
      local match = false

      for _, type in ipairs(types) do
        if task_type == type then
          match = true
          break
        end
      end

      if not match then
        table.insert(tasks_to_remove, node)
      end
    end
  end

  for i = #tasks_to_remove, 1, -1 do
    local start_row, _, end_row = tasks_to_remove[i]:range()
    vim.api.nvim_buf_set_lines(0, start_row, end_row + 1, false, {})
  end

  -- 2. eliminate empty headlines (headlines which are not followed by any tasks)
  local max_line = vim.api.nvim_buf_line_count(0)
  local was_empty_line_or_headline_or_eof = true -- it's EOF initially

  for i = max_line, 1, -1 do
    local node = get_node_for_cursor({ i, 0 })

    if node:type() == 'headline' and was_empty_line_or_headline_or_eof then
      vim.api.nvim_buf_set_lines(0, i - 1, i + 1, false, {})
      was_empty_line_or_headline_or_eof = true
    elseif node == root then
      was_empty_line_or_headline_or_eof = true
    else
      was_empty_line_or_headline_or_eof = false
    end
  end

  -- 3. eliminate multiple empty lines, only keep 1
  max_line = vim.api.nvim_buf_line_count(0)
  local empty_line_count = 0
  local was_eof = true -- it's EOF initially

  for i = max_line, 1, -1 do
    local node = get_node_for_cursor({ i, 0 })

    print(i, empty_line_count)
    if node == root then
      empty_line_count = empty_line_count + 1 + (was_eof and 1 or 0)
    elseif empty_line_count >= 2 then
      print('deleted', i, i + empty_line_count - 1)
      vim.api.nvim_buf_set_lines(0, i, i + empty_line_count - 1, false, {})
      empty_line_count = 0
    else
      empty_line_count = 0
    end

    was_eof = false
  end
end

M.is_configured = function()
  return configured
end

local options = {
  disable_default_highlights = false,
  disable_default_mappings = false,
  default_jump_group = 'all', -- possible values: all, open_and_ongoing
  wrap_jumps = true,
  verbose = false,
}
local configured = false

local function set_up_treesitter()
  vim.filetype.add({ extension = { xit = 'xit' } })
  vim.treesitter.language.add('xit', { path = PARSER_DIR .. '/xit.so' })
  vim.treesitter.language.register('xit', 'xit')

  local query_path = debug.getinfo(1, 'S').source:sub(2):match('(.*/)lua/') .. 'queries/xit/highlights.scm'
  local query_text = io.open(query_path):read('*a')
  vim.treesitter.query.set('xit', 'highlights', query_text)
end

M.setup = function(opts)
  opts = opts or {}
  options = vim.tbl_deep_extend('force', options, opts)
  configured = true

  if opts.verbose then
    print('Set up treesitter for xit.')
  end

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'xit',
    callback = function(ev)
      if opts.verbose then
        print('Entering .xit file and executing xit callback.')
      end

      if not vim.treesitter.language.get_lang(vim.bo.filetype) then
        print('No Treesitter parser for ' .. vim.bo.filetype)
      end

      vim.treesitter.start(ev.buf, 'xit')
    end,
  })

  local augroup = vim.api.nvim_create_augroup('xit_highlights_mappings', { clear = true })
  if not options.disable_default_highlights then
    set_highlighting()
    vim.api.nvim_create_autocmd('ColorScheme', {
      group = augroup,
      callback = function()
        set_highlighting()
      end,
    })
  end

  if not options.disable_default_mappings then
    set_mappings(M, augroup, options)
  end
end

return M
