if not jit then
    error("The RawTerm library requires LuaJIT FFI")
end

local ffi = require("ffi")
local band, bnot, bor = bit.band, bit.bnot, bit.bor
local floor = math.floor

local rawterm = {}

local C = ffi.C
ffi.cdef [[

    // Type Definitions
    typedef unsigned char cc_t;
    typedef unsigned int speed_t;
    typedef unsigned int tcflag_t;

    struct termios
        {
            tcflag_t c_iflag;
            tcflag_t c_oflag;
            tcflag_t c_cflag;
            tcflag_t c_lflag;
            cc_t c_line;
            cc_t c_cc[32];
            speed_t c_ispeed;
            speed_t c_ospeed;
        };

    struct winsize
        {
            unsigned short int ws_row;
            unsigned short int ws_col;
            unsigned short int ws_xpixel;
            unsigned short int ws_ypixel;
        };

    // Function Definitions
    int tcgetattr (int __fd, struct termios *__termios_p);

    int tcsetattr (int __fd, int __optional_actions,
              const struct termios *__termios_p);

    int ioctl (int __fd, unsigned long int __request, ...);

    char *strerror(int errnum);

    int errno;
]]

local iflags = {
    IGNBRK = 0000001,  -- Ignore break condition.
    BRKINT = 0000002,  -- Signal interrupt on break.
    IGNPAR = 0000004,  -- Ignore characters with parity errors.
    PARMRK = 0000010,  -- Mark parity and framing errors.
    INPCK = 0000020,   -- Enable input parity check.
    ISTRIP = 0000040,  -- Strip 8th bit off characters.
    INLCR = 0000100,   -- Map NL to CR on input.
    IGNCR = 0000200,   -- Ignore CR.
    ICRNL = 0000400,   -- Map CR to NL on input.
    IUCLC = 0001000,   -- Map uppercase characters to lowercase on input (not in POSIX).
    IXON = 0002000,    -- Enable start/stop output control.
    IXANY = 0004000,   -- Enable any character to restart output.
    IXOFF = 0010000,   -- Enable start/stop input control.
    IMAXBEL = 0020000, -- Ring bell when input queue is full (not in POSIX).  */
    IUTF8 = 0040000,   -- Input is UTF8 (not in POSIX).
}

local oflags = {
    OPOST = 0000001,  -- Post-process output.
    OLCUC = 0000002,  -- Map lowercase characters to uppercase on output. (not in POSIX).
    ONLCR = 0000004,  -- Map NL to CR-NL on output.
    OCRNL = 0000010,  -- Map CR to NL on output.
    ONOCR = 0000020,  -- No CR output at column 0.
    ONLRET = 0000040, -- NL performs CR function.
    OFILL = 0000100,  -- Use fill characters for delay.
    OFDEL = 0000200,  -- Fill is DEL.
}

local lflags = {
    ISIG = 0000001,   -- Enable signals.
    ICANON = 0000002, -- Canonical input (erase and kill processing).

    XCASE = 0000004,

    ECHO = 0000010,   -- Enable echo.
    ECHOE = 0000020,  -- Echo erase character as error-correcting backspace.
    ECHOK = 0000040,  -- Echo KILL.
    ECHONL = 0000100, -- Echo NL.
    NOFLSH = 0000200, -- Disable flush after interrupt or quit.
    TOSTOP = 0000400, -- Send SIGTTOU for background output.

    IEXTEN = 0100000, -- Enable implementation-defined input processing.
}

local cflags = {
    CSIZE  = 0000060,
      CS5  = 0000000,
      CS6  = 0000020,
      CS7  = 0000040,
      CS8  = 0000060,
    CSTOPB = 0000100,
    CREAD  = 0000200,
    PARENB = 0000400,
    PARODD = 0001000,
    HUPCL  = 0002000,
    CLOCAL = 0004000,
}

local tcs_attr = {
    TCSANOW   = 0,
    TCSADRAIN = 1,
    TCSAFLUSH = 2
}

local tcs_cc = {
    VINTR = 0,
    VQUIT = 1,
    VERASE = 2,
    VKILL = 3,
    VEOF = 4,
    VTIME = 5,
    VMIN = 6,
    VSWTC = 7,
    VSTART = 8,
    VSTOP = 9,
    VSUSP = 10,
    VEOL = 11,
    VREPRINT = 12,
    VDISCARD = 13,
    VWERASE = 14,
    VLNEXT = 15,
    VEOL2 = 16,
}

local STDIN_FILENO = 0
local STDOUT_FILENO = 1

local function die(cause)
    local errMsg = ffi.string(C.strerror(C.errno))
    error(cause .. " : " .. errMsg, 2)
end

local function copyStructPtr(def, struct)
    local holder = ffi.new(def)
    holder[0] = struct[0]
    return holder
end

local function default(ops, defaults)
    ops = ops or {}
    for k, v in pairs(defaults) do
        if ops[k] == nil then
            ops[k] = v
        end
    end

    return ops
end

local termiosStructDef = "struct termios[1]"
function rawterm.getTermios()
    local termios = ffi.new(termiosStructDef)
    if C.tcgetattr(STDIN_FILENO, termios) == -1 then die("tcgetattr") end

    return termios
end

local function genFlagFunc(type, value)
    return function(termios)
        termios[0][type] = band(termios[0][type], bnot(value))
    end
end

rawterm.disableEcho      = genFlagFunc("c_lflag", lflags.ECHO)
rawterm.disableCanonical = genFlagFunc("c_lflag", lflags.ICANON)
rawterm.disableSignals   = genFlagFunc("c_lflag", lflags.ISIG)
rawterm.disableLiteral   = genFlagFunc("c_lflag", lflags.IEXTEN)

rawterm.disableFlowCtl     = genFlagFunc("c_iflag", iflags.IXON)
rawterm.disableCRTranslate = genFlagFunc("c_iflag", iflags.ICRNL)
rawterm.disablecarriageOut = genFlagFunc("c_oflag", oflags.OPOST)

function rawterm.disableMisc(termios)
    termios[0].c_iflag = band(termios[0].c_iflag, 
        bnot(bor(iflags.BRKINT, iflags.INPCK, iflags.ISTRIP)))
    termios[0].c_cflag = bor(termios[0].c_cflag, cflags.CS8)
end

function rawterm.changeReadTimeout(termios, timeout)
    if timeout == 0 or not timeout then
        termios[0].c_cc[tcs_cc.VMIN] = 1
        termios[0].c_cc[tcs_cc.VTIME] = 0
    else
        termios[0].c_cc[tcs_cc.VMIN] = 0
        termios[0].c_cc[tcs_cc.VTIME] = timeout
    end
end


function rawterm.flushOptions(termios)
    local res = C.tcsetattr(STDIN_FILENO, tcs_attr.TCSAFLUSH, termios)
    if res == -1 then die("tcsetattr") end
    return true
end

local orig_termios
function rawterm.enableRawMode(options)
    orig_termios = rawterm.getTermios()
    local termios = copyStructPtr(termiosStructDef, orig_termios)

    options = default(options, {
        echo = false,
        canonical = false,

        signals = true,
        literal = false,

        flowctl = false,
        carriageIn = false,
        carriageOut = true,

        readtimeout = 0
    })

    if not options.echo then rawterm.disableEcho(termios) end
    if not options.canonical then rawterm.disableCanonical(termios) end

    if not options.signals then rawterm.disableSignals(termios) end
    if not options.literal then rawterm.disableLiteral(termios) end

    if not options.flowctl then rawterm.disableFlowCtl(termios) end
    if not options.carriageIn then rawterm.disableCRTranslate(termios) end
    if not options.carriageOut then rawterm.disablecarriageOut(termios) end

    if options.readtimeout then
        rawterm.changeReadTimeout(termios, options.readtimeout)
    end

    rawterm.disableMisc(termios)

    return rawterm.flushOptions(termios)
end

function rawterm.disableRawMode()
    if orig_termios then
        return rawterm.flushOptions(orig_termios)
    end
end

local getWindowSizeOption = 0x5413
function rawterm.getWindowSize()
    local wsize = ffi.new("struct winsize[1]")
    C.ioctl(STDOUT_FILENO, getWindowSizeOption, wsize)

    return wsize[0].ws_col, wsize[0].ws_row
end

function rawterm.getCursorPos()
    io.write("\27[6n")
    local res = ""
    while true do
        local c = io.read(1)
        if c == "R" then
            break
        end

        res = res .. c
    end

    local y, x = res:match("%[(%d+);(%d+)")
    return x, y
end

function rawterm.setCursorPos(x, y)
    io.write("\27[" .. floor(y) .. ";" .. floor(x) .. "H")
end

return rawterm
