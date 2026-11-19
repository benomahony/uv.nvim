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
    -- Picker integration: "auto" | "snacks" | "telescope" | false
    picker_integration = "auto",
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
- `:UVAutoActivateToggle` - Toggle auto-activate venv globally
- `:UVAutoActivateToggleBuffer` - Toggle auto-activate venv for current buffer

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

### Picker Integration

This plugin supports multiple UI picker integrations. Configure with the `picker_integration` option:

```lua
require('uv').setup({
  -- Options: "auto" | "snacks" | "telescope" | false
  picker_integration = "auto",  -- default
})
```

| Value | Description |
|-------|-------------|
| `"auto"` | Automatically detect available picker (tries Snacks first, then Telescope) |
| `"snacks"` | Explicitly use [Snacks.nvim](https://github.com/folke/snacks.nvim) picker |
| `"telescope"` | Explicitly use [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) picker |
| `false` | Disable picker integration |

**Note:** `true` is still supported for backwards compatibility (treated as `"auto"`).

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

-- Granular auto-activate control
uv.is_auto_activate_enabled()      -- Check if enabled (respects vim.b/vim.g)
uv.toggle_auto_activate_venv()     -- Toggle globally
uv.toggle_auto_activate_venv(true) -- Toggle buffer-local
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

### Granular Auto-Activate Venv Control

The `auto_activate_venv` setting can be toggled at runtime on a per-directory or per-buffer basis, similar to LazyVim's autoformat feature. This is useful when you want to disable auto-activation for specific projects.

#### Vim Variables

The plugin uses vim variables for granular control (buffer-local takes precedence over global):

- `vim.g.uv_auto_activate_venv` - Global setting (overrides config)
- `vim.b.uv_auto_activate_venv` - Buffer-local setting (overrides global)

#### Commands

- `:UVAutoActivateToggle` - Toggle auto-activate venv globally
- `:UVAutoActivateToggleBuffer` - Toggle auto-activate venv for current buffer

You can also set the vim variables directly:

```lua
vim.g.uv_auto_activate_venv = false  -- Disable globally
vim.b.uv_auto_activate_venv = true   -- Enable for current buffer
```

#### Per-Project Configuration

To disable auto-activation for a specific project, add to your project-local config (e.g., `.nvim.lua` or `.lazy.lua`):

```lua
vim.g.uv_auto_activate_venv = false
```

Or use an autocmd to set it based on directory:

```lua
vim.api.nvim_create_autocmd("DirChanged", {
  callback = function()
    -- Disable for specific directories
    if vim.fn.getcwd():match("some%-project") then
      vim.g.uv_auto_activate_venv = false
    else
      vim.g.uv_auto_activate_venv = nil  -- Use default config
    end
  end,
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

  -- Picker integration: "auto" | "snacks" | "telescope" | false
  -- "auto" tries snacks first, then telescope
  picker_integration = "auto",

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
