local comments = false
local keep = false
local dry_run = false
local path,name,extention
for _,a in ipairs(arg) do
	if a=="-h" or a == "--help" then
		print("playlist_split.lua")
		print("a too to split a soudfile in many smaller ones")
		print()
		print("give the file you want to split as argument")
		print("the songnames and durations will be read from a .txt file with the same name")
		print("the files syntax is described in playlist_format.txt")
		print("if there is are times or durations missing in the file the tool will calculate or assume the nessecary information")
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
		path,name,extention = a:match("^(.+/)([%w%.%-]+)(%.%w+)$")
	end
end

local time = dofile("timetables.lua")
local log_file = io.open(path.."playlist_split_log.txt","w")
local songs = {}

function log(msg)
	print(msg)
	log_file:write(msg)
end

function load_songs()
	local list_file = io.open(path..name..".txt","r")
	local global = {tracknum = 0}
	local function next_song()
		return {
			album = global.album,
			artist = global.artist,
		}
	end
	local song = next_song()

	for l in list_file:lines() do
		if l == ")" then
			table.insert(songs,song)
			song = nil
		elseif l == "(" then
			song = next_song()
		elseif l == ")(" then
			table.insert(songs,song)
			song = next_song()
		elseif l == "()" then
			table.insert(songs,next_song())
			song = nil
		else
			local t = l:sub(0,2)
			local c = ""
			if #l > 3 then
				c = l:sub(4)
			end
			if t=="Ti" then
				song.title = c
			elseif t=="St" then
				song.start = time.parse(c)
			elseif t=="En" then
				song.ending = time.parse(c)
			elseif t=="Du" then
				song.duration = time.parse(c)
			elseif t=="Al" then
				if song == nil then
					global.album = c
				else
					song.album = c
				end
			elseif t=="Ar" then
				if song == nil then
					global.artist = c
				else
					song.artist = c
				end
			elseif t=="Tn" then
				if c == "" then
					global.tracknum = global.tracknum + 1
				else
					global.tracknum = tonumber(c)
				end
				song.tracknum = global.tracknum
			end
		end
	end

	list_file:close()
end

load_songs()

function complete_songs()
	local last_song,next_song
	for i,song in pairs(songs) do
		_, next_song = next(songs,i)
		if not song.start then
			if song.ending and song.duration then
				song.start = song.ending - song.duration
			else
				if last_song then
					log("assuming track "..i.." starts at the end of the previous")
					song.start = last_song.ending
				else
					song.start = false
				end
			end
		end
		if not song.ending then
			if song.duration then
				song.ending = song.start + song.duration
			else
				if next_song then
					log("assuming track "..i.." ends at the start of the next")
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
				log("warning: track "..i.." ("..song.title..") starts at "..song.start.." and goes "..song.duration)
				log("the difference will cause it to end at a diferent time or have a different duration")
			end
		end
		last_song = song
	end
end
complete_songs()

function run_command(cline)
	if dry_run then
		print(cline)
	else
		os.execute(cline)
	end
end

function cline_metadata(cline,meta)
	if meta.title then
		table.insert(cline,"-metadata title=\""..meta.title.."\"")
	end

	if meta.artist then
		table.insert(cline,"-metadata artist=\""..meta.artist.."\"")
	end

	if meta.album then
		table.insert(cline,"-metadata album=\""..meta.album.."\"")
	end

	if meta.tracknum then
		table.insert(cline,"-metadata track=\""..meta.tracknum.."\"")
	end
end

function ss_trim(inp,out,ss,meta)
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
	table.insert(cline,"-i "..inp)
	-- remove comments
	if not comments then
		table.insert(cline,"-metadata comment=\"\" -metadata description=\"\"")
	end
	-- metadata
	cline_metadata(cline,meta)
	-- output
	table.insert(cline,out)
	run_command(table.concat(cline," "))
end

function to_trim(inp,out,to,meta)
	local cline = {
		-- command
		"ffmpeg",
		-- no user interaction
		"-nostdin",
		-- input
		"-i "..inp
	}
	if to then
		-- end
		table.insert(cline,"-to "..to)
	end
	-- remove comments
	if not comments then
		table.insert(cline,"-metadata comment=\"\" -metadata description=\"\"")
	end
	-- metadata
	cline_metadata(cline,meta)
	-- output
	table.insert(cline,out)
	run_command(table.concat(cline," "))
end

for i,s in pairs(songs) do
	local inp = "\""..path..name..extention.."\""
	local trim = "\""..path..name.." trim"..i..extention.."\""
	local title
	if not s.title then
		title = "\""..path..name.." track "..i..extention.."\""
	else
		title = "\""..path..s.title..extention.."\""
	end
	
	if i > #songs/2 then
		if s.start ~= false then
			ss_trim(inp,trim,s.start,s)
		else
			run_command("cp "..inp.." "..trim)
		end
		if s.duration ~= false then
			to_trim(trim,title,s.duration,s)
		else
			run_command("cp "..trim.." "..title)
		end
	else
		if s.ending ~= false then
			to_trim(inp,trim,s.ending,s)
		else
			run_command("cp "..inp.." "..trim)
		end
		if s.start ~= false then
			ss_trim(trim,title,s.start,s)
		else
			run_command("cp "..trim.." "..title)
		end
	end
	if not keep then
		run_command("rm "..trim)
	end
end

log_file:close()
