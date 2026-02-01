-- uv.nvim - Utility functions for testing and code parsing
-- These are pure functions that can be tested without mocking

local M = {}

---Parse buffer lines to extract imports
---@param lines string[] Array of code lines
---@return string[] imports Array of import statements
function M.extract_imports(lines)
    local imports = {}
    for _, line in ipairs(lines) do
        if line:match("^%s*import ") or line:match("^%s*from .+ import") then
            table.insert(imports, line)
        end
    end
    return imports
end

---Parse buffer lines to extract global variable assignments
---@param lines string[] Array of code lines
---@return string[] globals Array of global variable assignments
function M.extract_globals(lines)
    local globals = {}
    local in_class = false
    local class_indent = 0

    for _, line in ipairs(lines) do
        -- Detect class definitions to skip class variables
        if line:match("^%s*class ") then
            in_class = true
            local spaces = line:match("^(%s*)")
            class_indent = spaces and #spaces or 0
        end

        -- Check if we're exiting a class block
        if in_class and line:match("^%s*[^%s#]") then
            local spaces = line:match("^(%s*)")
            local current_indent = spaces and #spaces or 0
            if current_indent <= class_indent then
                in_class = false
            end
        end

        -- Detect global variable assignments (not in class, not inside functions)
        if not in_class and not line:match("^%s*def ") and line:match("^%s*[%w_]+ *=") then
            -- Check if it's not indented (global scope)
            if not line:match("^%s%s+") then
                table.insert(globals, line)
            end
        end
    end

    return globals
end

---Extract function definitions from code lines
---@param lines string[] Array of code lines
---@return string[] functions Array of function names
function M.extract_functions(lines)
    local functions = {}
    for _, line in ipairs(lines) do
        local func_name = line:match("^def%s+([%w_]+)%s*%(")
        if func_name then
            table.insert(functions, func_name)
        end
    end
    return functions
end

---Check if code is all indented (would cause syntax errors if run directly)
---@param code string The code to check
---@return boolean is_indented True if all non-empty lines are indented
function M.is_all_indented(code)
    for line in code:gmatch("[^\r\n]+") do
        if not line:match("^%s+") and line ~= "" then
            return false
        end
    end
    return true
end

---Detect the type of Python code
---@param code string The code to analyze
---@return table analysis Table with code type information
function M.analyze_code(code)
    local analysis = {
        is_function_def = code:match("^%s*def%s+[%w_]+%s*%(") ~= nil,
        is_class_def = code:match("^%s*class%s+[%w_]+") ~= nil,
        has_print = code:match("print%s*%(") ~= nil,
        has_assignment = code:match("=") ~= nil,
        has_for_loop = code:match("%s*for%s+") ~= nil,
        has_if_statement = code:match("%s*if%s+") ~= nil,
        is_comment_only = code:match("^%s*#") ~= nil,
        is_all_indented = M.is_all_indented(code),
    }

    -- Determine if it's a simple expression
    analysis.is_expression = not analysis.is_function_def
        and not analysis.is_class_def
        and not analysis.has_assignment
        and not analysis.has_for_loop
        and not analysis.has_if_statement
        and not analysis.has_print

    return analysis
end

---Extract function name from a function definition
---@param code string The code containing a function definition
---@return string|nil function_name The function name or nil
function M.extract_function_name(code)
    return code:match("def%s+([%w_]+)%s*%(")
end

---Check if a function is called in the given code
---@param code string The code to search
---@param func_name string The function name to look for
---@return boolean is_called True if the function is called
function M.is_function_called(code, func_name)
    -- Look for function_name() pattern but not the definition
    local pattern = func_name .. "%s*%("
    local def_pattern = "def%s+" .. func_name .. "%s*%("

    -- Count calls vs definitions
    local calls = 0
    local defs = 0

    for match in code:gmatch(pattern) do
        calls = calls + 1
    end

    for _ in code:gmatch(def_pattern) do
        defs = defs + 1
    end

    return calls > defs
end

---Generate Python code to wrap indented code in a function
---@param code string The indented code
---@return string wrapped_code The code wrapped in a function
function M.wrap_indented_code(code)
    local result = "def run_selection():\n"
    for line in code:gmatch("[^\r\n]+") do
        result = result .. "    " .. line .. "\n"
    end
    result = result .. "\n# Auto-call the wrapper function\n"
    result = result .. "run_selection()\n"
    return result
end

---Generate expression print wrapper
---@param expression string The expression to wrap
---@return string print_statement The print statement
function M.generate_expression_print(expression)
    local trimmed = expression:gsub("^%s+", ""):gsub("%s+$", "")
    return 'print(f"Expression result: {' .. trimmed .. '}")\n'
end

---Generate function call wrapper for auto-execution
---@param func_name string The function name
---@return string wrapper_code The wrapper code
function M.generate_function_call_wrapper(func_name)
    local result = '\nif __name__ == "__main__":\n'
    result = result .. '    print(f"Auto-executing function: ' .. func_name .. '")\n'
    result = result .. "    result = " .. func_name .. "()\n"
    result = result .. "    if result is not None:\n"
    result = result .. '        print(f"Return value: {result}")\n'
    return result
end

---Validate configuration structure
---@param config table The configuration to validate
---@return boolean valid True if valid
---@return string|nil error Error message if invalid
function M.validate_config(config)
    if type(config) ~= "table" then
        return false, "Config must be a table"
    end

    -- Check execution config
    if config.execution then
        if config.execution.terminal then
            local valid_terminals = { split = true, vsplit = true, tab = true }
            if not valid_terminals[config.execution.terminal] then
                return false, "Invalid terminal option: " .. tostring(config.execution.terminal)
            end
        end
        if config.execution.notification_timeout then
            if type(config.execution.notification_timeout) ~= "number" then
                return false, "notification_timeout must be a number"
            end
        end
    end

    -- Check keymaps config
    if config.keymaps ~= nil and config.keymaps ~= false and type(config.keymaps) ~= "table" then
        return false, "keymaps must be a table or false"
    end

    return true, nil
end

---Merge two configurations (deep merge)
---@param default table The default configuration
---@param override table The override configuration
---@return table merged The merged configuration
function M.merge_configs(default, override)
    if type(override) ~= "table" then
        return default
    end

    local result = {}

    -- Copy all default values
    for k, v in pairs(default) do
        if type(v) == "table" and type(override[k]) == "table" then
            result[k] = M.merge_configs(v, override[k])
        elseif override[k] ~= nil then
            result[k] = override[k]
        else
            result[k] = v
        end
    end

    -- Add any keys from override that aren't in default
    for k, v in pairs(override) do
        if result[k] == nil then
            result[k] = v
        end
    end

    return result
end

---Parse a visual selection from position markers
---@param lines string[] The buffer lines
---@param start_line number Starting line (1-indexed)
---@param start_col number Starting column (1-indexed)
---@param end_line number Ending line (1-indexed)
---@param end_col number Ending column (1-indexed)
---@return string selection The extracted text
function M.extract_selection(lines, start_line, start_col, end_line, end_col)
    if #lines == 0 then
        return ""
    end

    local selected_lines = {}
    for i = start_line, end_line do
        if lines[i] then
            table.insert(selected_lines, lines[i])
        end
    end

    if #selected_lines == 0 then
        return ""
    end

    -- Adjust last line to end at the column position
    if #selected_lines > 0 and end_col > 0 then
        selected_lines[#selected_lines] = selected_lines[#selected_lines]:sub(1, end_col)
    end

    -- Adjust first line to start at the column position
    if #selected_lines > 0 and start_col > 1 then
        selected_lines[1] = selected_lines[1]:sub(start_col)
    end

    return table.concat(selected_lines, "\n")
end

---Check if a path looks like a virtual environment
---@param path string The path to check
---@return boolean is_venv True if it appears to be a venv
function M.is_venv_path(path)
    if not path or path == "" then
        return false
    end
    -- Check for common venv patterns
    return path:match("%.venv$") ~= nil
        or path:match("/venv$") ~= nil
        or path:match("\\venv$") ~= nil
        or path:match("%.venv/") ~= nil
        or path:match("/venv/") ~= nil
end

---Build command string for running Python
---@param run_command string The base run command (e.g., "uv run python")
---@param file_path string The file to run
---@return string command The full command
function M.build_run_command(run_command, file_path)
    -- Simple shell escape for the file path
    local escaped_path = "'" .. file_path:gsub("'", "'\\''") .. "'"
    return run_command .. " " .. escaped_path
end

return M
