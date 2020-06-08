package.path = "../?.lua;" .. package.path
local rawterm = require("rawterm")

rawterm.enableRawMode({ signals = true })

local function isControlChar(c)
    if type(c) == "string" then c = c:byte() end

    return not (c >= 32 and c <= 126)
end

local function copyTable(t)
    local nt = {}
    for i = 1, #t do
        nt[i] = t[i]
    end

    return nt
end

local Key = {
    ENTER = 1,
    BACKSPACE = 2, DELETE = 3,

    UP = 4, RIGHT = 5, DOWN = 6, LEFT = 7,

    HOME = 8, END = 9,

    UNKNOWN = 9999
}

local singleEscapes = { A = Key.UP, B = Key.DOWN, C = Key.RIGHT, D = Key.LEFT
                      , H = Key.HOME, F = Key.END }
local function parseSpecial(c)
    if c == 13 then return Key.ENTER
    elseif c == 127 then return Key.BACKSPACE
    elseif c == 27 then
        -- Escape sequence
        local c2 = assert(io.read(1), "Empty escape sequence")

        if c2 == "[" then
            local c3 = assert(io.read(1), "Partial escape sequence")

            -- Check for single char escapes
            if singleEscapes[c3] then return singleEscapes[c3] end

            if c3 == "3" then
                local c4 = assert(io.read(1), "Partial escape sequence")

                if c4 == "~" then
                    return Key.DELETE
                end
            end
        end
    end

    return Key.UNKNOWN
end

local function read(prompt, history)
    history = copyTable(history or {})

    local historyPos = #history + 1
    history[historyPos] = ""

    local linePos = 0

    local scrolled = 0
    local startX, startY
    local windowWidth, windowHeight = rawterm.getWindowSize()

    local function getProjectedCursor()
        local xPos = ((startX + linePos - 1) % windowWidth) + 1
        local yPos = startY + math.floor((startX + linePos - 1) / windowWidth)

        return xPos, yPos
    end

    local function checkWindowOverflow(doScroll)
        -- Manage window overflow (line-wrap)
        if startX + #history[historyPos] > (scrolled + 1)*windowWidth then
            local oscroll = scrolled
            scrolled = math.floor((startX + #history[historyPos]) / windowWidth)

            if scrolled + startY > windowHeight then
                local diff = scrolled - oscroll
                startY = startY - diff

                if doScroll then
                    rawterm.scroll(diff)
                end
            end
        end
    end

    local function redrawToEnd(extra)
        local xPos, yPos
        if linePos == 0 then
            -- Special case at the very beginning we don't want to backwrite
            xPos, yPos = getProjectedCursor()
        else
            linePos = linePos - 1
            xPos, yPos = getProjectedCursor()
            linePos = linePos + 1
        end

        rawterm.setCursorPos(xPos, yPos)
        io.write(history[historyPos]:sub(linePos) .. (extra or ""))

        checkWindowOverflow(true)
    end

    local function redrawLine()
        rawterm.setCursorPos(startX, startY)
        rawterm.clearToLineEnd()

        for i = startY + 1, startY + scrolled do
            rawterm.setCursorPos(1, i)
            rawterm.clearLine()
        end

        rawterm.setCursorPos(startX, startY)

        io.write(history[historyPos])

        checkWindowOverflow(false)
    end

    local function updateCursor()
        if linePos < 0 then
            linePos = 0
        elseif linePos > #history[historyPos] then
            linePos = #history[historyPos]
        end

        rawterm.setCursorPos(getProjectedCursor())
    end

    local function insertChar(c)
        history[historyPos] =
            history[historyPos]:sub(1, linePos) ..
            c ..
            history[historyPos]:sub(linePos + 1)

        linePos = linePos + 1
    end

    local function deleteChar()
        history[historyPos] =
            history[historyPos]:sub(1, linePos - 1) ..
            history[historyPos]:sub(linePos + 1)

        linePos = linePos - 1
    end

    io.write(prompt or "")
    startX, startY = rawterm.getCursorPos()

    while true do
        local char = io.read(1) or "\0"

        if isControlChar(char) then
            local key = parseSpecial(char:byte())

            if key == Key.ENTER then
                linePos = #history[historyPos]
                updateCursor()

                print() -- To exit this line
                return history[historyPos]
            end

            if key == Key.LEFT then
                linePos = linePos - 1

            elseif key == Key.RIGHT then
                linePos = linePos + 1

            elseif key == Key.UP then
                historyPos = math.max(1, historyPos - 1)
                linePos = #history[historyPos]
                redrawLine()

            elseif key == Key.DOWN then
                historyPos = math.min(historyPos + 1, #history)
                linePos = #history[historyPos]
                redrawLine()

            elseif key == Key.HOME then
                linePos = 0

            elseif key == Key.END then
                linePos = #history[historyPos]

            elseif key == Key.BACKSPACE then
                if linePos > 0 then
                    deleteChar()

                    redrawToEnd(" ")
                end

            elseif key == Key.DELETE then
                if linePos < #history[historyPos] then
                    linePos = linePos + 1
                    updateCursor()

                    deleteChar()

                    redrawToEnd(" ")
                end
            end

            updateCursor()
        else -- Normal input
            insertChar(char)

            redrawToEnd()
            updateCursor()
        end
    end
end

local history = {}

print("Type 'quit' to quit.")
while true do
    local out = read("Tell me something: ", { history = history })

    if out == "quit" then
        print("Okay fine.")
        break
    end

    print("Wow, " .. out .. " is pretty interesting.")
    table.insert(history, out)
end

rawterm.disableRawMode()
