package.path = "../?.lua;" .. package.path
local rawterm = require("rawterm")

local carriageOut = false -- Whether to disable '\n' -> '\r\n' translation
rawterm.enableRawMode({
    signals = false, -- Disables terminal processing of Ctrl+C etc
    carriageOut = carriageOut
})

local function isControlChar(c)
    if type(c) == "string" then c = c:byte() end

    return not (c >= 32 and c <= 126)
end

local supplement = carriageOut and "" or "\r"

local function tuple(...) return table.concat({...}, ",") end
print("Window size: " .. tuple(rawterm.getWindowSize()) .. supplement)
print("Current cursor pos: " .. tuple(rawterm.getCursorPos()) .. supplement)
print("Press q to quit" .. supplement)
while true do
    local char = io.read(1) or "\0"

    if isControlChar(char) then
        print(char:byte() .. supplement)
    else
        print(char:byte(), ("(%s)"):format(char) .. supplement)
    end

    if char == "q" then
        break
    end
end

rawterm.disableRawMode()

print("Goodbye!")
