# RawTerm

> _LuaJIT FFI is required to use this library_

RawTerm is a Lua library that allows access to "non-canonical mode" for terminal input. This allows programs to read input from STDIN byte by byte without requiring the user to press &lt;Enter&gt;, and allows for reading characters not normally accessible like the arrow keys and function keys.

## Usage

```lua
local rawterm = require("rawterm")
rawterm.enableRawMode()

-- Run your program...

rawterm.disableRawMode()
```

You can also selectively disable/enable options:
```lua
rawterm.enableRawMode({
    signals = false, 
    readtimeout = 1, 
    carriageOut = carriageOut
})
```

These are the defaults:
```lua
{
    echo = false,       -- Whether the terminal should echo characters
    canonical = false,  -- Canonical Mode, proccesses input in lines, you probably want this turned off

    signals = true,     -- Terminal processing of signals like Ctrl+C Ctrl+Z etc
    literal = false,    -- Literal mode accesible by Ctrl+V

    flowctl = false,    -- Ctrl+S Ctrl+Q input flow control
    carriageIn = false, -- If on, terminals may translate \r\n inputs to \n. With this turned on <Enter> produces either \r or \n depending on the system
    carriageOut = true, -- Whether the terminal should translate \n coming from your program into \r\n

    readtimeout = 0,    -- If greather than 0, io.read will timeout after x/10th of a second
}
```

Most options are turned off by default (meaning that RawTerm will actively turn off those features in the terminal). But a select few are not for sensibility reasons:

- Signal Processing is left on by default to avoid situations where the user can't exit the program. Only turn this off once you've implemented a sane way to exit your program.
- Ouptut Carriage Return Processing is left on by default because generally you don't want to have to do `print("abc\r")`.
- Read Timeout is disabled (set to 0) by default because it causes `io.read` to return `nil` on timeouts which may be unexpected behavior.

Some miscellaneous functions:

```lua
rawterm.getWindowSize()

rawterm.getCursorPos()
rawterm.setCursorPos(x, y)
```
