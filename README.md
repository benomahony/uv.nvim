# uv.nvim

A Neovim plugin providing integration with the [uv](https://github.com/astral-sh/uv) Python package manager, offering a smooth workflow for Python development in Neovim.

## Features

- Run Python code directly from Neovim
- Execute selected code snippets with context preservation
- Run specific functions with automatic module imports
- Manage Python packages with uv commands
- Automatically activate virtual environments
- Integration with UI pickers (like Telescope and Snacks.nvim)

## Demo

<https://github.com/user-attachments/assets/c7d59646-d2a0-406a-8bec-cf7f4cf38b51>

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "benomahony/uv.nvim",
  -- Optional filetype to lazy load when you open a python file
  -- ft = { python }
  -- Optional dependency, but recommended:
  -- dependencies = {
  --   "folke/snacks.nvim"
  -- or
  --   "nvim-telescope/telescope.nvim"
  -- },
  opts = {
    picker_integration = true,
  },
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'benomahony/uv.nvim',
  -- Optional filetype to lazy load when you open a python file
  -- ft = { python }
  -- Optional dependency, but recommended:
  -- requires = {
  --   "folke/snacks.nvim"
  -- or
  --   "nvim-telescope/telescope.nvim"
  -- },
  config = function()
    require('uv').setup()
  end
}
```

You can customize any part of the configuration to fit your workflow.

## Requirements

- Neovim 0.7.0 or later
- [uv](https://github.com/astral-sh/uv) installed on your system
- For UI picker integration, a compatible UI picker (like [Snacks.nvim](https://github.com/folke/snacks.nvim) or [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim))

## Usage

### Commands

uv.nvim provides several commands:

- `:UVInit` - Initialize a new uv project
- `:UVRunFile` - Run the current Python file
- `:UVRunSelection` - Run the selected Python code
- `:UVRunFunction` - Run a specific function from the current file

### Default Keymaps

All keymaps use the `<leader>x` prefix by default:

- `<leader>x` - Show uv commands menu (requires UI picker integration)
- `<leader>xr` - Run current file
- `<leader>xs` - Run selected code (in visual mode)
- `<leader>xf` - Run a specific function
- `<leader>xe` - Environment management
- `<leader>xi` - Initialize uv project
- `<leader>xa` - Add a package
- `<leader>xd` - Remove a package
- `<leader>xc` - Sync packages

### Advanced Usage

#### Running Selected Code

The plugin intelligently handles running selected code by:

1. Preserving imports from the file
2. Including global variables for context
3. Auto-detecting code type (function, expression, etc.)
4. Adding appropriate wrappers when needed

Example:

```python
# In your file
import numpy as np

data = np.array([1, 2, 3])

# Select this function and run with <leader>xs
def process_data(arr):
    return arr.mean()
```

The plugin will automatically:

- Include the import
- Include the global variable `data`
- Add a call to the function if not present

#### Running Functions

When using `:UVRunFunction` or `<leader>xf`, the plugin:

1. Scans the current file for all function definitions
2. Shows a picker to select which function to run
3. Creates a proper module import context for the function
4. Captures and displays return values

### Integration with Snacks.nvim

This plugin integrates with [Snacks.nvim](https://github.com/folke/snacks.nvim) for UI components:

- Command picker
- Environment management
- Function selection

## API

For advanced usage or integration with other plugins:

```lua
local uv = require('uv')

-- Run a command with uv
uv.run_command('uv add pandas')

-- Activate a virtual environment
uv.activate_venv('/path/to/venv')

-- Run the current file
uv.run_file()

-- Run selected code
uv.run_python_selection()

-- Run a specific function
uv.run_python_function()
```

## Customization Examples

### Custom Keymaps

```lua
require('uv').setup({
  keymaps = {
    prefix = "<leader>u",  -- Change prefix to <leader>u
    -- Disable specific keymaps
    venv = false,
    init = false,
  }
})
```

### Different Run Command

```lua
require('uv').setup({
  execution = {
    run_command = "python -m",  -- Use standard Python instead of uv
  }
})
```

### No Keymaps

```lua
require('uv').setup({
  keymaps = false  -- Disable all keymaps
})
```

## Troubleshooting

- **Command execution errors**: Make sure uv is installed and in your PATH.
- **Virtual environment not activating**: Check if the `.venv` directory exists in your project root.
- **Output not showing**: Check notification settings in your Neovim configuration.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT

## Configuration

Here's the default configuration with all available options:

```lua
require('uv').setup({
  -- Auto-activate virtual environments when found
  auto_activate_venv = true,
  notify_activate_venv = true,

  -- Auto commands for directory changes
  auto_commands = true,

  -- Integration with snacks picker
  picker_integration = true,

  -- Keymaps to register (set to false to disable)
  keymaps = {
    prefix = "<leader>x",  -- Main prefix for uv commands
    commands = true,       -- Show uv commands menu (<leader>x)
    run_file = true,       -- Run current file (<leader>xr)
    run_selection = true,  -- Run selected code (<leader>xs)
    run_function = true,   -- Run function (<leader>xf)
    venv = true,           -- Environment management (<leader>xe)
    init = true,           -- Initialize uv project (<leader>xi)
    add = true,            -- Add a package (<leader>xa)
    remove = true,         -- Remove a package (<leader>xd)
    sync = true,           -- Sync packages (<leader>xc)
    sync_all = true,       -- Sync all packages, extras and groups (<leader>xC)
  },

  -- Execution options
  execution = {
    -- Python run command template
    run_command = "uv run python",

    -- Show output in notifications
    notify_output = true,

    -- Notification timeout in ms
    notification_timeout = 10000,
  },
})
```
