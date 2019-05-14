--TODO: gmatch instead of split
dofile("splitstring.lua")

--TODO: log file

local comments = false
local keep = false
local dry_run = false
local name
for _,a in ipairs(arg) do
	if a=="-h" or a == "--help" then
		print("playlist_split.lua")
		print("a too to split a soudfile in many smaller ones")
		print()
		print("give the file you want to split as argument")
		print("the songnames and durations will be read from a .txt file with the same name")
		print("this file needs the following syntax:")
		print("an ampty line marks the next song")
		print("T <title>", "sets the songs title")
		print("S <start>", "sets the songs starting time")
		print("D <duration>", "sets the songs duration")
		print("E <end>", "sets the songs ending time")
		print("if there is are times or durations missing the tool will calculate or assume the nessecary information")
		print()
		print("command line options:")
		print("-h or --help", "guess what ...")
		print("-c or --comments","doesn't remove the comment metadata from the output files")
		print("-k or --keep","doesn't remove the created trimming files (pretty useless tho)")
		print("-d or --dry","dry run, don't execute any commands only print them out")
		return
	elseif a=="-c" or a == "--comments" then
		comments = true
	elseif a=="-k" or a == "--keep" then
		keep = true
	elseif a=="-d" or a == "--dry" then
		dry_run = true
	else
		name = a:split(".")
	end
end
local extention = "."..table.remove(name)
local path = table.concat(name):split("/")
name = table.remove(path)
path = table.concat(path,"/") .."/"

local time = dofile("timetables.lua")

local songs = {}

function load_songs()
	local list_file = io.open(path..name..".txt","r")
	local song = {}

	for l in list_file:lines() do
		if l == "" then
			if next(song) then
				table.insert(songs,song)
				song = {}
			end
		end
		local t = l:sub(0,1)
		if t=="T" then
			song.title = l:sub(3)
		elseif t=="S" then
			song.start = time.parse(l:sub(3))
		elseif t=="E" then
			song.ending = time.parse(l:sub(3))
		elseif t=="D" then
			song.duration = time.parse(l:sub(3))
		end
	end

	list_file:close()

	if next(song) then
		table.insert(songs,song)
		song = {}
	end
end

load_songs()

function complete_songs()
	local last_song,next_song
	for i,song in pairs(songs) do
		_, next_song = next(songs,i)
		if not song.title then
			song.title = name.." track "..i
		end
		if not song.start then
			if song.ending and song.duration then
				song.start = song.ending - song.duration
			else
				print("assuming track "..i.." starts at the end of the previous")
				song.start = last_song.ending
			end
		end
		if not song.ending then
			if song.duration then
				song.ending = song.start + song.duration
			else
				if next_song then
					print("assuming track "..i.." ends at the start of the next")
					song.ending = next_song.start
				else
					song.ending = false
				end
			end
		end
		if not song.duration then
			if song.ending == false then
				-- until the end
				song.duration = false
			else
				song.duration = song.ending - song.start
			end
		end
		if song.duration then
			if song.start + song.duration ~= song.ending then
				print("warning: track "..i.." ("..song.title..") starts at "..song.start.." and goes "..song.duration)
				print("the difference will cause it to end at a diferent time or have a different duration")
			end
		end
		last_song = song
	end
end
complete_songs()

function ss_trim(inp,out,ss)
	local cline = {
		-- command
		"ffmpeg",
		-- no user interaction
		"-nostdin"
	}
	if ss then
		-- seek
		table.insert(cline,"-ss "..ss)
	end
	-- input
	table.insert(cline,"-i \""..inp.."\"")
	-- remove comments
	if not comments then
		table.insert(cline,"-metadata comment=\"\" -metadata description=\"\"")
	end
	-- output
	table.insert(cline,"\""..out.."\"")
	if dry_run then
		print(table.concat(cline," "))
	else
		os.execute(table.concat(cline," "))
	end
end

function to_trim(inp,out,to)
	local cline = {
		-- command
		"ffmpeg",
		-- no user interaction
		"-nostdin",
		-- input
		"-i \""..inp.."\""
	}
	if to then
		-- end
		table.insert(cline,"-to "..to)
	end
	-- remove comments
	if not comments then
		table.insert(cline,"-metadata comment=\"\" -metadata description=\"\"")
	end
	-- output
	table.insert(cline,"\""..out.."\"")
	if dry_run then
		print(table.concat(cline," "))
	else
		os.execute(table.concat(cline," "))
	end
end

--TODO: don't pre trim if start at 0 or end at eof

for i,s in pairs(songs) do
	local inp = path..name..extention
	local trim = path..name.." trim"..i..extention
	local title = path..s.title..extention
	if i > #songs/2 then
		ss_trim(inp,trim,s.start)
		to_trim(trim,title,s.duration)
	else
		to_trim(inp,trim,s.ending)
		ss_trim(trim,title,s.start)
	end
	if not keep then
		if dry_run then
			print("rm "..path..name.." trim"..i..extention)
		else
			os.execute("rm \""..path..name.." trim"..i..extention.."\"")
		end
	end
end
