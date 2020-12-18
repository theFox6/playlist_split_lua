--- #boolean whether commands should not be run
local dry_run = false
--- #boolean whether to delete trim files
local keep = false
--- #string the path of the audio
local path
--- #string the name of the audio
local name
--- #string the extension of the audio
local extention

---
-- Show the help.
-- Shows the help to this script.
--
-- @function show_help
local function show_help()
  print("simple_cutter.lua")
  print("a tool to split an audio file in many smaller ones")
  print()
  print("give the file you want to split as argument")
  print("durations will be read from a .txt file with the same name")
  print("each line of the .txt file should contain a timestamp, where the next song ends")
  print("the part from the last timestamp until the end will be contained in the output as well")
  print()
  print("command line options:")
  print("-h or --help", "guess what ...")
  print("-d or --dry","dry run, don't execute any commands only print them out")
  print("-k or --keep", "keep files created by trimming steps")
end

-- fetch and parse command line
for _,a in ipairs(arg) do
  if a=="-h" or a == "--help" then
    show_help()
    return
  elseif a=="-d" or a == "--dry" then
    dry_run = true
  elseif a=="-k" or a == "--keep" then
    keep = true
  else
    path,name,extention = a:match("^\"?(.+/)([^/%.]+)(%.%w+)\"?$")
    if path == nil then
      print("warning: file path \"".. a .. "\" could not be parsed")
    end
  end
end

if not path then
  show_help()
  return
end

--- #timetables the timetables module
local times = dofile("timetables.lua")
--- #file the log file
local log_file = io.open(path.."simple_cutter_log.txt","w")
--- #table durations of the songs in the playlist
local songs = {}

---
-- Write a log message.
-- Writes a message to the standard out and the log file
--
-- @function log
-- @param #string msg the message to be written
local function log(msg)
  print(msg)
  log_file:write(msg.."\n")
end

---
-- Load the songs.
-- Parse the songs from the playlist file.
--
-- @function load_songs()
local function load_songs()
  local list_file = io.open(path..name..".txt","r")

  local last = times.newTime()
  for l in list_file:lines() do
    if l:sub(0,2) == "--" then
      log(l)
    elseif l ~= "" then
      local cur = times.parse(l)
      table.insert(songs,cur-last)
      last = cur
    end
  end

  list_file:close()
end

load_songs()

--[[ dump all songs
print("song ending times:")
for _,s in pairs(songs) do
  log(tostring(s))
end
log("<end of file>")
--]]

---
-- Run a command.
-- Execute a command or print it out if this is a dry_run.
--
-- @function run_command
-- @param #string cline the command to be run
local function run_command(cline)
  if dry_run then
    print(cline)
  else
    os.execute(cline)
  end
end

---
-- Trim the sound file by seeking to a position.
-- Copy the sound of an audio to another starting at a certain position.
--
-- @function ss_trim
-- @param #string inp the file to be streamed from
-- @param #string out the file to be written to
-- @param #time ss the time to be seeked to
local function ss_trim(inp,out,ss)
  local cline = {
    -- command
    "ffmpeg",
    -- no user interaction
    "-nostdin",
  }
  if ss then
    -- seek
    table.insert(cline,"-ss "..ss)
  end
  -- input
  table.insert(cline,"-i "..inp)
  -- do not reencode
  table.insert(cline,"-c copy")
  -- output
  table.insert(cline,out)
  run_command(table.concat(cline," "))
end


---
-- Trim the sound file by streaming until a position.
-- Copy the sound of an audio to another ending at a certain position.
--
-- @function to_trim
-- @param #string inp the file to be streamed from
-- @param #string out the file to be written to
-- @param #time to the time to be written until
local function to_trim(inp,out,to)
  local cline = {
    -- command
    "ffmpeg",
    -- no user interaction
    "-nostdin",
    -- input
    "-i "..inp,
    -- do not reencode
    "-c copy"
  }
  if to then
    -- end
    table.insert(cline,"-to "..to)
  end
  -- output
  table.insert(cline,out)
  run_command(table.concat(cline," "))
end

local last_trim = false
for i,s in pairs(songs) do
  local inp = "\""..path..name..extention.."\""
  local trim = "\""..path..name.." trim"..i..extention.."\""
  local title = "\""..path..name.." track "..i..extention.."\""

  if last_trim then
    to_trim(last_trim,title,s)
    ss_trim(last_trim,trim,s)
    if not keep then
      run_command("rm "..last_trim)
    end
  else
    to_trim(inp,title,s)
    ss_trim(inp,trim,s)
  end
  last_trim = trim
end
local etrim = "\""..path..name.." track "..(#songs+1)..extention.."\""
if keep then
  run_command("cp "..last_trim.." "..etrim)
else
  run_command("mv "..last_trim.." "..etrim)
end

log_file:close()
