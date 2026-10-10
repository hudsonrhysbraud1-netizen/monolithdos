-- COMMAND.PRG - DOS-like command interpreter for Monolith Disk Operating System (M-DOS)

local running = true
local currentDir = "/"
local currentDrive = "A"
local historySize = 20
local commandHistory = {}
local historyIndex = 0

-- Color codes
local COLOR_WHITE = 0xFFFFFF
local COLOR_GRAY = 0xAAAAAA
local COLOR_YELLOW = 0xFFFF00
local COLOR_RED = 0xFF0000
local COLOR_GREEN = 0x00FF00

-- ==================== UTILITY FUNCTIONS ====================
local function print(text)
  local w, h = os.display.getResolution()
  os.display.write(tostring(text) .. "\n")
end

local function clearScreen()
  os.display.clear()
  os.display.write("", 1, 1)
end

local function normalizePath(path)
  if not path or path == "" then return currentDir end
  if not os.string.startsWith(path, "/") then
    path = os.path.concat(currentDir, path)
  end
  
  -- Normalize path: handle . and ..
  path = path:gsub("//+", "/")  -- Remove duplicate slashes
  
  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      -- Go up one directory
      if #parts > 0 then
        table.remove(parts)
      end
    elseif part ~= "." then
      -- Skip "." and add everything else
      table.insert(parts, part)
    end
  end
  
  -- Reconstruct path
  if #parts == 0 then
    return "/"
  else
    return "/" .. table.concat(parts, "/")
  end
end

local function formatSize(bytes)
  if bytes < 1024 then
    return string.format("%d B", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB", bytes / 1024)
  else
    return string.format("%.1f MB", bytes / (1024 * 1024))
  end
end

local function formatDate(timestamp)
  -- Simple date format (timestamp is in seconds)
  local days = math.floor(timestamp / 86400)
  return string.format("%d days ago", days)
end

-- ==================== INPUT HANDLING ====================
local function readLine(prompt)
  if prompt then
    os.display.write(prompt)
  end
  
  local line = ""
  local cursorPos = 0
  local startX = os.display.cursorX
  local startY = os.display.cursorY
  local historyPos = 0
  
  local function drawCursor()
    os.display.cursorX = startX + cursorPos
    os.display.cursorY = startY
    local cursorChar = cursorPos < #line and line:sub(cursorPos + 1, cursorPos + 1) or " "
    os.display.setBackground(0xFFFFFF)
    os.display.setForeground(0x000000)
    os.display.write(cursorChar)
    os.display.setBackground(0x000000)
    os.display.setForeground(COLOR_WHITE)
  end
  
  local function redrawLine()
    -- Clear the entire line area first
    os.display.cursorX = startX
    os.display.cursorY = startY
    os.display.setBackground(0x000000)
    os.display.setForeground(COLOR_WHITE)
    local w, _ = os.display.getResolution()
    local clearWidth = math.max(0, w - startX + 1)
    if clearWidth > 0 then
      os.display.write(string.rep(" ", clearWidth))
    end
    
    -- Redraw the line content
    os.display.cursorX = startX
    os.display.cursorY = startY
    os.display.write(line)
    
    -- Draw cursor
    drawCursor()
  end
  
  drawCursor()
  
  while true do
    local eventType, addr, char, code = os.event.pull(nil, "key_down")
    
    if eventType then
      -- Enter
      if code == os.keyboard.keys.enter then
        -- Clear the cursor and redraw the line normally before submitting
        os.display.cursorX = startX
        os.display.cursorY = startY
        os.display.setBackground(0x000000)
        os.display.setForeground(COLOR_WHITE)
        local w = os.display.getResolution()
        os.display.write(string.rep(" ", w - startX + 1))
        os.display.cursorX = startX
        os.display.cursorY = startY
        os.display.write(line)
        os.display.write("\n")
        return line
      -- Backspace
      elseif code == os.keyboard.keys.back then
        if cursorPos > 0 then
          line = line:sub(1, cursorPos - 1) .. line:sub(cursorPos + 1)
          cursorPos = cursorPos - 1
          redrawLine()
        end
      -- Up arrow - previous command
      elseif code == os.keyboard.keys.up then
        if historyPos < #commandHistory then
          historyPos = historyPos + 1
          line = commandHistory[#commandHistory - historyPos + 1] or ""
          cursorPos = #line
          redrawLine()
        end
      -- Down arrow - next command
      elseif code == os.keyboard.keys.down then
        if historyPos > 0 then
          historyPos = historyPos - 1
          if historyPos == 0 then
            line = ""
          else
            line = commandHistory[#commandHistory - historyPos + 1] or ""
          end
          cursorPos = #line
          redrawLine()
        end
      -- Left arrow
      elseif code == os.keyboard.keys.left then
        if cursorPos > 0 then
          -- Redraw old cursor position
          os.display.cursorX = startX + cursorPos
          os.display.cursorY = startY
          os.display.setBackground(0x000000)
          os.display.setForeground(COLOR_WHITE)
          os.display.write(cursorPos <= #line and line:sub(cursorPos, cursorPos) or " ")
          
          cursorPos = cursorPos - 1
          drawCursor()
        end
      -- Right arrow
      elseif code == os.keyboard.keys.right then
        if cursorPos < #line then
          -- Redraw old cursor position
          os.display.cursorX = startX + cursorPos
          os.display.cursorY = startY
          os.display.setBackground(0x000000)
          os.display.setForeground(COLOR_WHITE)
          os.display.write(line:sub(cursorPos + 1, cursorPos + 1))
          
          cursorPos = cursorPos + 1
          drawCursor()
        end
      -- Home
      elseif code == os.keyboard.keys.home then
        if cursorPos < #line then
          os.display.cursorX = startX + cursorPos
          os.display.cursorY = startY
          os.display.setBackground(0x000000)
          os.display.setForeground(COLOR_WHITE)
          os.display.write(line:sub(cursorPos + 1, cursorPos + 1))
        end
        cursorPos = 0
        drawCursor()
      -- End
      elseif code == os.keyboard.keys["end"] then
        if cursorPos < #line then
          os.display.cursorX = startX + cursorPos
          os.display.cursorY = startY
          os.display.setBackground(0x000000)
          os.display.setForeground(COLOR_WHITE)
          os.display.write(line:sub(cursorPos + 1, cursorPos + 1))
        end
        cursorPos = #line
        drawCursor()
      -- Regular character
      elseif char > 0 and char < 256 and not os.keyboard.isControl(char) then
        line = line:sub(1, cursorPos) .. string.char(char) .. line:sub(cursorPos + 1)
        cursorPos = cursorPos + 1
        redrawLine()
      end
    end
  end
end

-- ==================== BUILT-IN COMMANDS ====================
local commands = {}

commands.help = function(args)
  -- Check if asking for help on a specific program
  if args[1] then
    local programPath = normalizePath(args[1])
    
    -- Add .PRG extension if not present
    if not os.string.endsWith(programPath:lower(), ".prg") then
      programPath = programPath .. ".PRG"
    end
    
    if not os.fs.exists(programPath) then
      os.display.setForeground(COLOR_RED)
      print("Program not found: " .. programPath)
      os.display.setForeground(COLOR_WHITE)
      return
    end
    
    -- Read the program file
    local code = os.fs.readAll(programPath)
    if not code then
      os.display.setForeground(COLOR_RED)
      print("Failed to read program")
      os.display.setForeground(COLOR_WHITE)
      return
    end
    
    -- Look for help text in comments at the start of the file
    -- Format: -- HELP: description here
    local helpText = nil
    for line in code:gmatch("[^\r\n]+") do
      if line:match("^%s*%-%-HELP:%s*(.+)") then
        helpText = line:match("^%s*%-%-HELP:%s*(.+)")
        break
      end
      -- Stop at first non-comment line
      if not line:match("^%s*%-%-") and line:match("%S") then
        break
      end
    end
    
    if helpText then
      os.display.setForeground(COLOR_YELLOW)
      print("Help for " .. args[1] .. ":")
      os.display.setForeground(COLOR_WHITE)
      print(helpText)
    else
      os.display.setForeground(COLOR_YELLOW)
      print("No help available for " .. args[1])
      os.display.setForeground(COLOR_WHITE)
    end
    return
  end
  
  -- Show general help
  os.display.setForeground(COLOR_YELLOW)
  print("Available commands:")
  os.display.setForeground(COLOR_WHITE)
  print("  DIR [path]         - List directory contents")
  print("  CD <path>          - Change directory")
  print("  TYPE <file>        - Display file contents")
  print("  DEL <file>         - Delete a file")
  print("  COPY <src> <dst>   - Copy a file")
  print("  REN <old> <new>    - Rename a file")
  print("  MD <path>          - Make directory")
  print("  RD <path>          - Remove directory")
  print("  CLS                - Clear screen")
  print("  MEM                - Show memory info")
  print("  POWER              - Show power info")
  print("  TIME               - Show system uptime")
  print("  RUN <file>         - Run a .PRG file")
  print("  EDIT <file>        - Simple file editor (Ctrl+S save, Ctrl+X exit)")
  print("  SYS <drive>        - Copy system files to drive")
  print("  FORMAT <drive>     - Format a tape drive")
  print("  FDISK              - Manage disk drives")
  print("  FTAPE              - Manage tape drives")
  print("  REBOOT             - Reboot computer")
  print("  SHUTDOWN           - Shutdown computer")
  print("  HELP [program]     - Show this help or help for a program")
  print("  EXIT               - Exit to BIOS")
  print("")
  print("Use HELP <program.prg> to see help for a specific program")
end

commands.dir = function(args)
  local path = normalizePath(args[1])
  
  if not os.fs.exists(path) then
    os.display.setForeground(COLOR_RED)
    print("Directory not found: " .. path)
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  if not os.fs.isDirectory(path) then
    os.display.setForeground(COLOR_RED)
    print("Not a directory: " .. path)
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  local entries = os.fs.list(path)
  if not entries then
    os.display.setForeground(COLOR_RED)
    print("Failed to list directory")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  print("\nDirectory of " .. path)
  print("")
  
  local fileCount = 0
  local dirCount = 0
  local totalSize = 0
  
  for _, entry in ipairs(entries) do
    local fullPath = os.path.concat(path, entry)
    local isDir = os.fs.isDirectory(fullPath)
    local size = isDir and 0 or (os.fs.size(fullPath) or 0)
    
    if isDir then
      os.display.setForeground(COLOR_YELLOW)
      print(string.format("%-30s <DIR>", entry))
      dirCount = dirCount + 1
    else
      os.display.setForeground(COLOR_WHITE)
      print(string.format("%-30s %10s", entry, formatSize(size)))
      fileCount = fileCount + 1
      totalSize = totalSize + size
    end
  end
  
  os.display.setForeground(COLOR_GRAY)
  print(string.format("\n%d File(s) %s", fileCount, formatSize(totalSize)))
  print(string.format("%d Dir(s)", dirCount))
  os.display.setForeground(COLOR_WHITE)
end

commands.cd = function(args)
  if not args[1] then
    print(currentDir)
    return
  end
  
  local path = normalizePath(args[1])
  
  if not os.fs.exists(path) then
    os.display.setForeground(COLOR_RED)
    print("Directory not found")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  if not os.fs.isDirectory(path) then
    os.display.setForeground(COLOR_RED)
    print("Not a directory")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  currentDir = path
end

commands.type = function(args)
  if not args[1] then
    print("Usage: TYPE <file>")
    return
  end
  
  local path = normalizePath(args[1])
  
  if not os.fs.exists(path) then
    os.display.setForeground(COLOR_RED)
    print("File not found")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  local content = os.fs.readAll(path)
  if content then
    print(content)
  else
    os.display.setForeground(COLOR_RED)
    print("Failed to read file")
    os.display.setForeground(COLOR_WHITE)
  end
end

commands.del = function(args)
  if not args[1] then
    print("Usage: DEL <file>")
    return
  end
  
  local path = normalizePath(args[1])
  
  if not os.fs.exists(path) then
    os.display.setForeground(COLOR_RED)
    print("File not found")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  local ok, err = os.fs.remove(path)
  if ok then
    os.display.setForeground(COLOR_GREEN)
    print("Deleted: " .. path)
    os.display.setForeground(COLOR_WHITE)
  else
    os.display.setForeground(COLOR_RED)
    print("Failed to delete: " .. tostring(err))
    os.display.setForeground(COLOR_WHITE)
  end
end

commands.copy = function(args)
  if not args[1] or not args[2] then
    print("Usage: COPY <source> <destination>")
    return
  end
  
  local src = normalizePath(args[1])
  local dst = normalizePath(args[2])
  
  -- Handle cross-drive copying
  local srcDrive = currentDrive
  local dstDrive = currentDrive
  
  -- Parse source drive if specified
  if args[1]:match("^[A-Za-z]:") then
    srcDrive = args[1]:sub(1, 1):upper()
    src = args[1]:sub(3)
    if not src:match("^/") then
      src = "/" .. src
    end
  end
  
  -- Parse destination drive if specified
  if args[2]:match("^[A-Za-z]:") then
    dstDrive = args[2]:sub(1, 1):upper()
    dst = args[2]:sub(3)
    if not dst:match("^/") then
      dst = "/" .. dst
    end
  end
  
  -- Get source and destination proxies
  local srcProxy = os.fs.drives[srcDrive]
  local dstProxy = os.fs.drives[dstDrive]
  
  if not srcProxy then
    os.display.setForeground(COLOR_RED)
    print("Source drive not found: " .. srcDrive .. ":")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  if not dstProxy then
    os.display.setForeground(COLOR_RED)
    print("Destination drive not found: " .. dstDrive .. ":")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  -- Check if source exists
  if not srcProxy.exists(src) then
    os.display.setForeground(COLOR_RED)
    print("Source file not found: " .. srcDrive .. ":" .. src)
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  -- If destination is a directory, append source filename
  if dstProxy.exists(dst) and dstProxy.isDirectory(dst) then
    local filename = os.path.name(src)
    dst = os.path.concat(dst, filename)
  end
  
  -- Read from source
  local handle = srcProxy.open(src, "r")
  if not handle then
    os.display.setForeground(COLOR_RED)
    print("Failed to read source file")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  local content = ""
  repeat
    local chunk = srcProxy.read(handle, math.huge)
    content = content .. (chunk or "")
  until not chunk
  srcProxy.close(handle)
  
  -- Write to destination
  local dstHandle = dstProxy.open(dst, "w")
  if not dstHandle then
    os.display.setForeground(COLOR_RED)
    print("Failed to write destination file")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  dstProxy.write(dstHandle, content)
  dstProxy.close(dstHandle)
  
  os.display.setForeground(COLOR_GREEN)
  print("Copied: " .. srcDrive .. ":" .. src .. " -> " .. dstDrive .. ":" .. dst)
  os.display.setForeground(COLOR_WHITE)
end

commands.ren = function(args)
  if not args[1] or not args[2] then
    print("Usage: REN <oldname> <newname>")
    return
  end
  
  local src = normalizePath(args[1])
  local dst = normalizePath(args[2])
  
  local ok, err = os.fs.rename(src, dst)
  if ok then
    os.display.setForeground(COLOR_GREEN)
    print("Renamed: " .. src .. " -> " .. dst)
    os.display.setForeground(COLOR_WHITE)
  else
    os.display.setForeground(COLOR_RED)
    print("Failed to rename: " .. tostring(err))
    os.display.setForeground(COLOR_WHITE)
  end
end

commands.md = function(args)
  if not args[1] then
    print("Usage: MD <directory>")
    return
  end
  
  local path = normalizePath(args[1])
  local ok, err = os.fs.makeDirectory(path)
  if ok then
    os.display.setForeground(COLOR_GREEN)
    print("Created directory: " .. path)
    os.display.setForeground(COLOR_WHITE)
  else
    os.display.setForeground(COLOR_RED)
    print("Failed to create directory: " .. tostring(err))
    os.display.setForeground(COLOR_WHITE)
  end
end

commands.rd = function(args)
  if not args[1] then
    print("Usage: RD <directory>")
    return
  end
  
  local path = normalizePath(args[1])
  local ok, err = os.fs.remove(path)
  if ok then
    os.display.setForeground(COLOR_GREEN)
    print("Removed directory: " .. path)
    os.display.setForeground(COLOR_WHITE)
  else
    os.display.setForeground(COLOR_RED)
    print("Failed to remove directory: " .. tostring(err))
    os.display.setForeground(COLOR_WHITE)
  end
end

commands.cls = function(args)
  clearScreen()
end

commands.mem = function(args)
  local free = os.system.freeMemory()
  local total = os.system.totalMemory()
  local used = total - free
  
  os.display.setForeground(COLOR_YELLOW)
  print("Memory Information:")
  os.display.setForeground(COLOR_WHITE)
  print(string.format("  Total:  %s", formatSize(total)))
  print(string.format("  Used:   %s (%.1f%%)", formatSize(used), (used / total) * 100))
  print(string.format("  Free:   %s (%.1f%%)", formatSize(free), (free / total) * 100))
end

commands.power = function(args)
  local energy = os.system.energy()
  local maxEnergy = os.system.maxEnergy()
  
  os.display.setForeground(COLOR_YELLOW)
  print("Power Information:")
  os.display.setForeground(COLOR_WHITE)
  print(string.format("  Current: %.0f / %.0f", energy, maxEnergy))
  print(string.format("  Percent: %.1f%%", (energy / maxEnergy) * 100))
end

commands.time = function(args)
  local uptime = os.system.uptime()
  local hours = math.floor(uptime / 3600)
  local minutes = math.floor((uptime % 3600) / 60)
  local seconds = math.floor(uptime % 60)
  
  print(string.format("System uptime: %02d:%02d:%02d", hours, minutes, seconds))
end

commands.run = function(args)
  if not args[1] then
    print("Usage: RUN <file>")
    return
  end
  
  local path = normalizePath(args[1])
  
  if not os.fs.exists(path) then
    os.display.setForeground(COLOR_RED)
    print("File not found")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  local code = os.fs.readAll(path)
  if not code then
    os.display.setForeground(COLOR_RED)
    print("Failed to read file")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  local func, err = load(code, "=" .. path, "t", _G)
  if not func then
    os.display.setForeground(COLOR_RED)
    print("Syntax error: " .. tostring(err))
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  local ok, result = pcall(func)
  if not ok then
    os.display.setForeground(COLOR_RED)
    print("Runtime error: " .. tostring(result))
    os.display.setForeground(COLOR_WHITE)
  end
end

commands.edit = function(args)
  if not args[1] then
    print("Usage: EDIT <file>")
    return
  end
  
  local path = normalizePath(args[1])
  local content = ""
  local lines = {}
  
  if os.fs.exists(path) then
    content = os.fs.readAll(path) or ""
    for line in content:gmatch("[^\r\n]*") do
      table.insert(lines, line)
    end
  end
  
  -- If file is empty, start with one empty line
  if #lines == 0 then
    table.insert(lines, "")
  end
  
  local w, h = os.display.getResolution()
  local currentLine = 1
  local scrollOffset = 0
  local modified = false
  local statusHeight = 2
  local editHeight = h - statusHeight
  
  local function redraw()
    clearScreen()
    
    -- Draw file content
    for i = 1, editHeight do
      local lineNum = i + scrollOffset
      if lineNum <= #lines then
        os.display.cursorY = i
        os.display.cursorX = 1
        
        -- Line number
        os.display.setForeground(COLOR_GRAY)
        os.display.write(string.format("%3d ", lineNum))
        
        -- Line content
        os.display.setForeground(COLOR_WHITE)
        local lineText = lines[lineNum] or ""
        if #lineText > w - 5 then
          lineText = lineText:sub(1, w - 5)
        end
        os.display.write(lineText)
      end
    end
    
    -- Draw status bar
    os.display.cursorY = h - 1
    os.display.cursorX = 1
    os.display.setBackground(0x444444)
    os.display.setForeground(COLOR_WHITE)
    local status = string.format(" %s %s Line %d/%d", path, modified and "[Modified]" or "", currentLine, #lines)
    os.display.write(status .. string.rep(" ", w - #status))
    
    -- Draw help bar
    os.display.cursorY = h
    os.display.cursorX = 1
    local help = " Ctrl+S: Save  Ctrl+X: Exit  Arrows: Navigate"
    os.display.write(help .. string.rep(" ", w - #help))
    os.display.setBackground(0x000000)
    os.display.setForeground(COLOR_WHITE)
    
    -- Position cursor on current line
    local displayLine = currentLine - scrollOffset
    if displayLine < 1 then
      scrollOffset = currentLine - 1
      redraw()
      return
    elseif displayLine > editHeight then
      scrollOffset = currentLine - editHeight
      redraw()
      return
    end
    
    os.display.cursorY = displayLine
    os.display.cursorX = 5 + #(lines[currentLine] or "")
  end
  
  local function editLine(lineNum)
    local displayLine = lineNum - scrollOffset
    os.display.cursorY = displayLine
    os.display.cursorX = 5
    
    local line = lines[lineNum] or ""
    os.display.setForeground(COLOR_WHITE)
    os.display.write(line .. string.rep(" ", w - 5 - #line))
    
    local cursorPos = #line
    
    -- Draw cursor
    local function drawCursor()
      os.display.cursorX = 5 + cursorPos
      os.display.cursorY = displayLine
      local cursorChar = cursorPos < #line and line:sub(cursorPos + 1, cursorPos + 1) or " "
      os.display.setBackground(0xFFFFFF)
      os.display.setForeground(0x000000)
      os.display.write(cursorChar)
      os.display.setBackground(0x000000)
      os.display.setForeground(COLOR_WHITE)
    end
    
    drawCursor()
    
    while true do
      local eventType, addr, char, code = os.event.pull()
      
      if eventType == "key_down" then
        -- Ctrl+S - Save
        if code == os.keyboard.keys.s and os.keyboard.isControlDown() then
          lines[lineNum] = line  -- Save current line first
          local newContent = table.concat(lines, "\n")
          local ok, err = os.fs.writeAll(path, newContent)
          if ok then
            modified = false
            redraw()
            -- Show save confirmation briefly
            os.display.cursorY = h - 1
            os.display.cursorX = 1
            os.display.setBackground(0x00FF00)
            os.display.setForeground(0x000000)
            os.display.write(" Saved! " .. string.rep(" ", w - 8))
            os.system.sleep(0.5)
            redraw()
            drawCursor()
          else
            -- Show error briefly
            os.display.cursorY = h - 1
            os.display.cursorX = 1
            os.display.setBackground(0xFF0000)
            os.display.write(" Error: " .. tostring(err) .. string.rep(" ", w - 8 - #tostring(err)))
            os.system.sleep(2)
            redraw()
            drawCursor()
          end
        -- Ctrl+X - Exit
        elseif code == os.keyboard.keys.x and os.keyboard.isControlDown() then
          lines[lineNum] = line  -- Save current line
          return "exit"
        -- Arrow keys
        elseif code == os.keyboard.keys.up then
          lines[lineNum] = line
          if os.keyboard.isShiftDown() then
            -- Shift+Up: scroll view up
            if scrollOffset > 0 then
              scrollOffset = scrollOffset - 1
              redraw()
            end
            drawCursor()
          else
            -- Normal up: move to previous line
            return "up"
          end
        elseif code == os.keyboard.keys.down then
          lines[lineNum] = line
          if os.keyboard.isShiftDown() then
            -- Shift+Down: scroll view down
            if scrollOffset < #lines - editHeight then
              scrollOffset = scrollOffset + 1
              redraw()
            end
            drawCursor()
          else
            -- Normal down: move to next line
            return "down"
          end
        elseif code == os.keyboard.keys.left then
          if cursorPos > 0 then
            -- Redraw character at old cursor position
            os.display.cursorX = 5 + cursorPos
            os.display.cursorY = displayLine
            os.display.setBackground(0x000000)
            os.display.setForeground(COLOR_WHITE)
            os.display.write(cursorPos <= #line and line:sub(cursorPos, cursorPos) or " ")
            
            cursorPos = cursorPos - 1
            drawCursor()
          end
        elseif code == os.keyboard.keys.right then
          if cursorPos < #line then
            -- Redraw character at old cursor position
            os.display.cursorX = 5 + cursorPos
            os.display.cursorY = displayLine
            os.display.setBackground(0x000000)
            os.display.setForeground(COLOR_WHITE)
            os.display.write(line:sub(cursorPos + 1, cursorPos + 1))
            
            cursorPos = cursorPos + 1
            drawCursor()
          end
        elseif code == os.keyboard.keys.home then
          -- Redraw old cursor position
          if cursorPos < #line then
            os.display.cursorX = 5 + cursorPos
            os.display.cursorY = displayLine
            os.display.setBackground(0x000000)
            os.display.setForeground(COLOR_WHITE)
            os.display.write(line:sub(cursorPos + 1, cursorPos + 1))
          end
          
          cursorPos = 0
          drawCursor()
        elseif code == os.keyboard.keys["end"] then
          -- Redraw old cursor position
          if cursorPos < #line then
            os.display.cursorX = 5 + cursorPos
            os.display.cursorY = displayLine
            os.display.setBackground(0x000000)
            os.display.setForeground(COLOR_WHITE)
            os.display.write(line:sub(cursorPos + 1, cursorPos + 1))
          end
          
          cursorPos = #line
          drawCursor()
        -- Enter - Next line
        elseif code == os.keyboard.keys.enter then
          lines[lineNum] = line
          modified = true
          return "next"
        -- Backspace
        elseif code == os.keyboard.keys.back then
          if cursorPos > 0 then
            line = line:sub(1, cursorPos - 1) .. line:sub(cursorPos + 1)
            cursorPos = cursorPos - 1
            os.display.cursorX = 5
            os.display.cursorY = displayLine
            os.display.setBackground(0x000000)
            os.display.setForeground(COLOR_WHITE)
            os.display.write(line .. "  ")
            modified = true
            drawCursor()
          elseif lineNum > 1 then
            -- Merge with previous line
            local prevLine = lines[lineNum - 1]
            lines[lineNum - 1] = prevLine .. line
            table.remove(lines, lineNum)
            modified = true
            return "prev"
          end
        -- Regular character
        elseif char > 0 and not os.keyboard.isControl(char) then
          if #line < w - 6 then
            line = line:sub(1, cursorPos) .. string.char(char) .. line:sub(cursorPos + 1)
            cursorPos = cursorPos + 1
            os.display.cursorX = 5
            os.display.cursorY = displayLine
            os.display.setBackground(0x000000)
            os.display.setForeground(COLOR_WHITE)
            os.display.write(line)
            modified = true
            drawCursor()
          end
        end
      end
    end
  end
  
  redraw()
  
  while true do
    local result = editLine(currentLine)
    
    if result == "exit" then
      if modified then
        os.display.cursorY = h - 1
        os.display.cursorX = 1
        os.display.setBackground(0x444444)
        os.display.write(" Save changes? (Y/N) " .. string.rep(" ", w - 21))
        os.display.setBackground(0x000000)
        
        local answer = ""
        while true do
          local eventType, addr, char, code = os.event.pull(nil, "key_down")
          if char > 0 then
            answer = string.char(char):upper()
            break
          end
        end
        
        if answer == "Y" then
          local newContent = table.concat(lines, "\n")
          os.fs.writeAll(path, newContent)
        end
      end
      clearScreen()
      return
    elseif result == "next" then
      if currentLine < #lines then
        currentLine = currentLine + 1
      else
        table.insert(lines, "")
        currentLine = #lines
      end
      redraw()
    elseif result == "up" then
      if currentLine > 1 then
        currentLine = currentLine - 1
      end
      redraw()
    elseif result == "down" then
      if currentLine < #lines then
        currentLine = currentLine + 1
      else
        table.insert(lines, "")
        currentLine = #lines
      end
      redraw()
    elseif result == "prev" then
      if currentLine > 1 then
        currentLine = currentLine - 1
      end
      redraw()
    end
  end
end

commands.reboot = function(args)
  print("Rebooting...")
  os.system.sleep(1)
  os.system.shutdown(true)
end

commands.shutdown = function(args)
  print("Shutting down...")
  os.system.sleep(1)
  os.system.shutdown(false)
end

commands.exit = function(args)
  running = false
end

commands.sys = function(args)
  if not args[1] then
    print("Usage: SYS <drive>")
    print("Example: SYS B:")
    return
  end
  
  local letter = args[1]:upper()
  if not letter:match("^[A-Z]:$") then
    os.display.setForeground(COLOR_RED)
    print("Invalid drive format. Use format like: B:")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  letter = letter:sub(1, 1)
  local targetDrive = os.fs.getDrive(letter)
  
  if not targetDrive then
    os.display.setForeground(COLOR_RED)
    print("Drive " .. letter .. ": not found")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  if letter == "A" then
    os.display.setForeground(COLOR_RED)
    print("Cannot copy system to boot drive")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  -- Check if it's a tape drive
  if targetDrive.type == "tapefs" then
    os.display.setForeground(COLOR_RED)
    print("Cannot make tape drives bootable")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  os.display.setForeground(COLOR_YELLOW)
  print("Copying system files to " .. letter .. ":...")
  os.display.setForeground(COLOR_WHITE)
  
  -- Get boot drive
  local bootDrive = os.fs.drives["A"]
  
  -- Copy init.lua
  local files = {"init.lua", "OS.SYS", "COMMAND.PRG"}
  local success = true
  
  for _, filename in ipairs(files) do
    print("  Copying " .. filename .. "...")
    
    -- Read from boot drive
    local handle = bootDrive.open(filename, "r")
    if not handle then
      os.display.setForeground(COLOR_RED)
      print("  Failed to read " .. filename)
      os.display.setForeground(COLOR_WHITE)
      success = false
      break
    end
    
    local content = ""
    repeat
      local chunk = bootDrive.read(handle, math.huge)
      content = content .. (chunk or "")
    until not chunk
    bootDrive.close(handle)
    
    -- Write to target drive
    local targetHandle = targetDrive.open(filename, "w")
    if not targetHandle then
      os.display.setForeground(COLOR_RED)
      print("  Failed to write " .. filename)
      os.display.setForeground(COLOR_WHITE)
      success = false
      break
    end
    
    targetDrive.write(targetHandle, content)
    targetDrive.close(targetHandle)
  end
  
  if success then
    os.display.setForeground(COLOR_GREEN)
    print("System files copied successfully!")
    print("Drive " .. letter .. ": is now bootable")
    os.display.setForeground(COLOR_WHITE)
  end
end

commands.format = function(args)
  if not args[1] then
    print("Usage: FORMAT <drive>")
    print("Example: FORMAT C:")
    return
  end
  
  local letter = args[1]:upper()
  if not letter:match("^[A-Z]:$") then
    os.display.setForeground(COLOR_RED)
    print("Invalid drive format. Use format like: C:")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  letter = letter:sub(1, 1)
  
  -- Check if it's a tape
  local tapeProxy = os.tape.tapes[letter]
  if not tapeProxy then
    os.display.setForeground(COLOR_RED)
    print("Drive " .. letter .. ": is not a tape drive")
    print("Use FTAPE to assign tape drives first")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  os.display.setForeground(COLOR_YELLOW)
  print("WARNING: This will erase all data on tape " .. letter .. ":")
  os.display.setForeground(COLOR_WHITE)
  print("Are you sure? (Y/N)")
  local answer = readLine("> "):upper()
  
  if answer ~= "Y" then
    print("Format cancelled")
    return
  end
  
  print("Formatting tape " .. letter .. ":...")
  local ok, err = os.tape.formatTape(tapeProxy)
  
  if ok then
    os.display.setForeground(COLOR_GREEN)
    print("Tape formatted successfully!")
    print("Drive " .. letter .. ": is now ready to use")
    os.display.setForeground(COLOR_WHITE)
  else
    os.display.setForeground(COLOR_RED)
    print("Format failed: " .. tostring(err))
    os.display.setForeground(COLOR_WHITE)
  end
end

commands.fdisk = function(args)
  os.display.setForeground(COLOR_YELLOW)
  print("Fixed Disk Manager")
  print("==================")
  os.display.setForeground(COLOR_WHITE)
  print("")
  
  -- List current drive assignments
  print("Current drive assignments:")
  local drives = os.fs.listDrives()
  if #drives == 0 then
    print("  (none)")
  else
    for _, drive in ipairs(drives) do
      print(string.format("  %s: %s", drive.letter, drive.address:sub(1, 8)))
    end
  end
  print("")
  
  -- List available filesystems (excluding tmpfs)
  print("Available filesystems:")
  local component = component
  local tmpAddr = computer.tmpAddress()
  local fsIndex = 1
  local filesystems = {}
  for addr, ctype in component.list("filesystem", true) do
    if addr ~= tmpAddr then
      print(string.format("  %d. %s (%s)", fsIndex, addr:sub(1, 8), ctype))
      filesystems[fsIndex] = addr
      fsIndex = fsIndex + 1
    end
  end
  
  if fsIndex == 1 then
    print("  (none available)")
    return
  end
  
  print("")
  print("Enter number to assign (or 0 to cancel):")
  local choice = readLine("> ")
  choice = tonumber(choice)
  
  if not choice or choice == 0 then
    print("Cancelled")
    return
  end
  
  if not filesystems[choice] then
    os.display.setForeground(COLOR_RED)
    print("Invalid choice")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  print("Enter drive letter (A-Z):")
  local letter = readLine("> ")
  letter = os.string.trim(letter):upper()
  
  if #letter ~= 1 or letter < "A" or letter > "Z" then
    os.display.setForeground(COLOR_RED)
    print("Invalid drive letter")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  local ok, err = os.fs.setDrive(letter, filesystems[choice])
  if ok then
    os.display.setForeground(COLOR_GREEN)
    print(string.format("Drive %s: assigned to %s", letter, filesystems[choice]:sub(1, 8)))
    os.display.setForeground(COLOR_WHITE)
  else
    os.display.setForeground(COLOR_RED)
    print("Failed to assign drive: " .. tostring(err))
    os.display.setForeground(COLOR_WHITE)
  end
end

commands.ftape = function(args)
  os.display.setForeground(COLOR_YELLOW)
  print("Tape Drive Manager")
  print("==================")
  os.display.setForeground(COLOR_WHITE)
  print("")
  print("Tape drives can be used as filesystems after formatting.")
  print("Use FORMAT <drive> to format a tape for file storage.")
  print("")
  
  -- List current tape assignments
  print("Current tape assignments:")
  local tapes = os.tape.listTapes()
  if #tapes == 0 then
    print("  (none)")
  else
    for _, tape in ipairs(tapes) do
      print(string.format("  %s: %s", tape.letter, tape.address:sub(1, 8)))
    end
  end
  print("")
  
  -- List available tape drives
  print("Available tape drives:")
  local component = component
  local tapeIndex = 1
  local tapeDrives = {}
  for addr, ctype in component.list("tape_drive", true) do
    print(string.format("  %d. %s", tapeIndex, addr:sub(1, 8)))
    tapeDrives[tapeIndex] = addr
    tapeIndex = tapeIndex + 1
  end
  
  if tapeIndex == 1 then
    print("  (none available)")
    return
  end
  
  print("")
  print("Enter number to assign (or 0 to cancel):")
  local choice = readLine("> ")
  choice = tonumber(choice)
  
  if not choice or choice == 0 then
    print("Cancelled")
    return
  end
  
  if not tapeDrives[choice] then
    os.display.setForeground(COLOR_RED)
    print("Invalid choice")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  print("Enter drive letter (A-Z):")
  local letter = readLine("> ")
  letter = os.string.trim(letter):upper()
  
  if #letter ~= 1 or letter < "A" or letter > "Z" then
    os.display.setForeground(COLOR_RED)
    print("Invalid drive letter")
    os.display.setForeground(COLOR_WHITE)
    return
  end
  
  local ok, err = os.tape.setTape(letter, tapeDrives[choice])
  if ok then
    os.display.setForeground(COLOR_GREEN)
    print(string.format("Tape %s: assigned to %s", letter, tapeDrives[choice]:sub(1, 8)))
    print("Use FORMAT " .. letter .. ": to format it as a filesystem")
    os.display.setForeground(COLOR_WHITE)
  else
    os.display.setForeground(COLOR_RED)
    print("Failed to assign tape: " .. tostring(err))
    os.display.setForeground(COLOR_WHITE)
  end
end

-- ==================== COMMAND PARSER ====================
local function parseCommand(input)
  input = os.string.trim(input)
  if input == "" then return nil, {} end
  
  -- Check if it's a drive change command (e.g., "D:")
  if input:match("^[A-Za-z]:$") then
    local letter = input:sub(1, 1):upper()
    -- Check both filesystems and tapes
    if os.fs.getDrive(letter) then
      currentDrive = letter
      os.fs.setCurrentDrive(letter)
      currentDir = "/"
      return nil, {}
    elseif os.tape.getTape(letter) then
      os.display.setForeground(COLOR_YELLOW)
      print("Note: " .. letter .. ": is a tape drive, not a filesystem")
      os.display.setForeground(COLOR_WHITE)
      return nil, {}
    else
      os.display.setForeground(COLOR_RED)
      print("Invalid drive: " .. letter .. ":")
      os.display.setForeground(COLOR_WHITE)
      return nil, {}
    end
  end
  
  local parts = os.string.split(input, " ")
  local cmd = table.remove(parts, 1)
  return string.lower(cmd), parts
end

-- ==================== MAIN LOOP ====================
local function main()
  clearScreen()
  
  os.display.setForeground(COLOR_YELLOW)
  print("Monolith Disk Operating System (M-DOS)")
  print("Version 1.02")
  os.display.setForeground(COLOR_WHITE)
  print("")
  
  -- Show connected drives
  local component = component
  local bootAddr = computer.getBootAddress()
  os.display.setForeground(COLOR_GREEN)
  print("Boot drive: A: (" .. bootAddr:sub(1, 8) .. ")")
  os.display.setForeground(COLOR_WHITE)
  print("")
  
  print("Connected filesystems:")
  local driveCount = 0
  local tmpAddr = computer.tmpAddress()
  for addr, ctype in component.list("filesystem", true) do
    -- Skip tmpfs
    if addr ~= tmpAddr then
      driveCount = driveCount + 1
      local isBootDrive = (addr == bootAddr)
      local proxy = component.proxy(addr)
      local label = proxy.getLabel() or "Unlabeled"
      local capacity = proxy.spaceTotal and proxy.spaceTotal() or 0
      local deviceType = "Filesystem"
      
      if ctype == "filesystem" then
        -- Try to determine if it's a floppy or hard drive based on capacity
        if capacity < 1024 * 1024 then
          deviceType = "Floppy"
        else
          deviceType = "Hard Drive"
        end
      end
      
      if isBootDrive then
        os.display.setForeground(COLOR_GREEN)
        print(string.format("  A: %s - %s (%s)", addr:sub(1, 8), formatSize(capacity), deviceType))
        os.display.setForeground(COLOR_WHITE)
      else
        -- Check if already assigned
        local assigned = false
        for letter, driveProxy in pairs(os.fs.drives) do
          if driveProxy.address == addr then
            os.display.setForeground(COLOR_YELLOW)
            print(string.format("  %s: %s - %s (%s)", letter, addr:sub(1, 8), formatSize(capacity), deviceType))
            os.display.setForeground(COLOR_WHITE)
            assigned = true
            break
          end
        end
        if not assigned then
          print(string.format("     %s - %s (%s) [unassigned]", addr:sub(1, 8), formatSize(capacity), deviceType))
        end
      end
    end
  end
  
  -- Show connected tape drives
  print("")
  print("Connected tape drives:")
  local tapeCount = 0
  for addr, ctype in component.list("tape_drive", true) do
    tapeCount = tapeCount + 1
    local proxy = component.proxy(addr)
    local size = proxy.getSize and proxy.getSize() or 0
    local label = proxy.getLabel and proxy.getLabel() or "No Tape"
    
    -- Check if already assigned
    local assigned = false
    local isFormatted = false
    for letter, tapeProxy in pairs(os.tape.tapes) do
      if tapeProxy.address == addr then
        assigned = true
        -- Check if formatted
        local fs = os.tape.readTapeFS(tapeProxy)
        isFormatted = (fs ~= nil)
        
        os.display.setForeground(COLOR_YELLOW)
        if isFormatted then
          print(string.format("  %s: %s - %s (TapeFS - Ready)", letter, addr:sub(1, 8), formatSize(size)))
        else
          print(string.format("  %s: %s - %s (Tape - Not Formatted)", letter, addr:sub(1, 8), formatSize(size)))
        end
        os.display.setForeground(COLOR_WHITE)
        break
      end
    end
    if not assigned then
      print(string.format("     %s - %s (Tape Drive) [unassigned]", addr:sub(1, 8), formatSize(size)))
    end
  end
  
  if tapeCount == 0 then
    print("  (none)")
  end
  
  if driveCount > 1 or tapeCount > 0 then
    print("")
    os.display.setForeground(COLOR_GRAY)
    if driveCount > 1 then
      print("Use FDISK to assign drive letters to unassigned filesystems")
    end
    if tapeCount > 0 then
      print("Use FTAPE to assign drive letters to tape drives")
    end
    os.display.setForeground(COLOR_WHITE)
  end
  
  print("")
  print("Type HELP for available commands")
  print("")
  
  while running do
    local prompt = currentDrive .. ":" .. currentDir .. "> "
    local input = readLine(prompt)
    
    if input and input ~= "" then
      -- Add to command history
      if #commandHistory == 0 or commandHistory[#commandHistory] ~= input then
        table.insert(commandHistory, input)
        if #commandHistory > historySize then
          table.remove(commandHistory, 1)
        end
      end
      
      local cmd, args = parseCommand(input)
      
      if cmd and commands[cmd] then
        commands[cmd](args)
      elseif cmd then
        os.display.setForeground(COLOR_RED)
        print("Unknown command: " .. cmd)
        print("Type HELP for available commands")
        os.display.setForeground(COLOR_WHITE)
      end
    end
  end
  
  print("Goodbye!")
end

-- Start the command interpreter
main()
