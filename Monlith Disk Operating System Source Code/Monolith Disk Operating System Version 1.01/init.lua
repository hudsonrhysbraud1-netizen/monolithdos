-- init.lua - Bootstrap loader for Monolith Disk Operating System (M-DOS)
-- This file loads OS.SYS and then executes COMMAND.PRG

local component = component
local computer = computer

-- Find the boot filesystem
local bootfs = component.proxy(computer.getBootAddress())

-- Find tmpfs for faster performance
local tmpfs = nil
local tmpAddr = computer.tmpAddress()
if tmpAddr then
  tmpfs = component.proxy(tmpAddr)
end

-- Load and execute OS.SYS to set up system environment
local handle, reason = bootfs.open("OS.SYS", "r")
if not handle then
  error("Failed to load OS.SYS: " .. tostring(reason))
end

local ossys = ""
repeat
  local chunk = bootfs.read(handle, math.huge)
  ossys = ossys .. (chunk or "")
until not chunk
bootfs.close(handle)

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

-- Now load and execute COMMAND.PRG
handle, reason = bootfs.open("COMMAND.PRG", "r")
if not handle then
  error("Failed to load COMMAND.PRG: " .. tostring(reason))
end

local cmdprog = ""
repeat
  local chunk = bootfs.read(handle, math.huge)
  cmdprog = cmdprog .. (chunk or "")
until not chunk
bootfs.close(handle)

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
  error("Failed to start COMMAND.PRG: " .. tostring(err))
end