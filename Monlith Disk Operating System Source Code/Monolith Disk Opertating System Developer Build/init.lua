-- init.lua - Bootstrap loader for Monolith Disk Operating System (M-DOS)
-- This file loads OS.SYS and then executes COMMAND.PRG
-- Version 1.1

local component = component
local computer = computer

-- Check for Safe Mode FIRST (holding Shift during boot)
local keyboard = component.list("keyboard", true)()
local safeMode = false
if keyboard then
  local kb = component.proxy(keyboard)
  if kb and kb.isShiftDown and kb.isShiftDown() then
    safeMode = true
    local gpu = component.proxy(component.list("gpu")())
    if gpu then
      gpu.set(1, 1, "** SAFE MODE ** (Only OS.SYS loaded)")
    end
  end
end

-- Find the boot filesystem
local bootfs = component.proxy(computer.getBootAddress())

-- Find tmpfs for faster performance
local tmpfs = nil
local tmpAddr = computer.tmpAddress()
if tmpAddr then
  tmpfs = component.proxy(tmpAddr)
end

-- Helper function to load a file
local function loadFile(filename)
  local handle, reason = bootfs.open(filename, "r")
  if not handle then
    return nil, reason
  end
  
  local content = ""
  repeat
    local chunk = bootfs.read(handle, math.huge)
    content = content .. (chunk or "")
  until not chunk
  bootfs.close(handle)
  
  return content
end

-- Load and execute OS.SYS to set up system environment
local ossys, reason = loadFile("OS.SYS")
if not ossys then
  error("Failed to load OS.SYS: " .. tostring(reason))
end

-- Copy OS.SYS to tmpfs for faster access
if tmpfs then
  local tmpHandle = tmpfs.open("OS.SYS", "w")
  if tmpHandle then
    tmpfs.write(tmpHandle, ossys)
    tmpfs.close(tmpHandle)
  end
end

-- Execute OS.SYS to initialize the system
local init, reason = load(ossys, "=OS.SYS", "t", _G)
if not init then
  error("Failed to parse OS.SYS: " .. tostring(reason))
end

local ok, err = pcall(init)
if not ok then
  error("Failed to initialize OS.SYS: " .. tostring(err))
end

-- Load CONFIG.INI if it exists
local config = {}
local configData = loadFile("CONFIG.INI")
if configData then
  -- Simple INI parser
  local currentSection = "GENERAL"
  for line in configData:gmatch("[^\r\n]+") do
    line = line:match("^%s*(.-)%s*$")  -- Trim whitespace
    
    if line:match("^%[.+%]$") then
      -- Section header
      currentSection = line:match("^%[(.+)%]$")
      config[currentSection] = config[currentSection] or {}
    elseif line:match("^[^;#]") and line ~= "" then
      -- Key=Value pair (ignore comments starting with ; or #)
      local key, value = line:match("^([^=]+)=(.*)$")
      if key and value then
        key = key:match("^%s*(.-)%s*$")
        value = value:match("^%s*(.-)%s*$")
        config[currentSection] = config[currentSection] or {}
        config[currentSection][key] = value
      end
    end
  end
end

-- Make config available globally
_G.CONFIG = config

-- Load additional .SYS files from CONFIG.INI (unless in Safe Mode)
if not safeMode and config.SYSTEM and config.SYSTEM.LOAD then
  local sysFiles = {}
  for file in config.SYSTEM.LOAD:gmatch("[^,]+") do
    file = file:match("^%s*(.-)%s*$")  -- Trim
    table.insert(sysFiles, file)
  end
  
  for _, sysFile in ipairs(sysFiles) do
    local sysCode, reason = loadFile(sysFile)
    if sysCode then
      -- Copy to tmpfs
      if tmpfs then
        local tmpHandle = tmpfs.open(sysFile, "w")
        if tmpHandle then
          tmpfs.write(tmpHandle, sysCode)
          tmpfs.close(tmpHandle)
        end
      end
      
      -- Execute the .SYS file
      local sysFunc, reason = load(sysCode, "=" .. sysFile, "t", _G)
      if sysFunc then
        local ok, err = pcall(sysFunc)
        if not ok then
          -- Non-fatal: just print error and continue
          local gpu = component.proxy(component.list("gpu")())
          if gpu then
            gpu.set(1, 3, "Warning: Failed to load " .. sysFile .. ": " .. tostring(err))
          end
        else
          -- Success message
          local gpu = component.proxy(component.list("gpu")())
          if gpu then
            local line = 2
            -- Find next available line
            for i = 2, 10 do
              local text = ""
              for x = 1, 80 do
                local char = gpu.get(x, i)
                if char and char ~= " " then
                  text = text .. char
                end
              end
              if text == "" or text:match("^%s*$") then
                line = i
                break
              end
            end
            gpu.set(1, line, sysFile .. " loaded successfully")
          end
        end
      end
    else
      local gpu = component.proxy(component.list("gpu")())
      if gpu then
        gpu.set(1, 3, "Warning: Could not read " .. sysFile)
      end
    end
  end
  
  -- Small delay to show messages
  computer.pullSignal(1.5)
end

-- Now load and execute COMMAND.PRG
local cmdprog, reason = loadFile("COMMAND.PRG")
if not cmdprog then
  error("Failed to load COMMAND.PRG: " .. tostring(reason))
end

-- Copy COMMAND.PRG to tmpfs
if tmpfs then
  local tmpHandle = tmpfs.open("COMMAND.PRG", "w")
  if tmpHandle then
    tmpfs.write(tmpHandle, cmdprog)
    tmpfs.close(tmpHandle)
  end
end

-- Execute COMMAND.PRG
local command, reason = load(cmdprog, "=COMMAND.PRG", "t", _G)
if not command then
  error("Failed to parse COMMAND.PRG: " .. tostring(reason))
end

local ok, err = pcall(command)
if not ok then
  local gpu = component.proxy(component.list("gpu")())
  if gpu then
    gpu.set(1, 5, "Failed to start COMMAND.PRG: " .. tostring(err))
    gpu.set(1, 6, "Press any key to see full error...")
    computer.pullSignal()
  end
  error("Failed to start COMMAND.PRG: " .. tostring(err))
end