--[[
Copyright (C) 2013-2014 Draios inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

-- Chisel description
description = "Print the data read and written for any FD. Combine this script with a filter to restrict what it shows. This chisel is compatible with containers using the sysdig -pc or -pcontainer argument, otherwise no container information will be shown. (Blue represents  [Write], and Red represents [Read] for all data except when the -pc or -pcontainer argument is used. If used the container.name and container.id will be represented as: Green [host], and Cyan [container]) Container information will contain '[]' around container.name and container.id.";
short_description = "Print the data read and written by processes.";
category = "I/O";

args =
{
	{
		name = "disable_color",
		description = "Set to 'disable_colors' if you want to disable color output",
		argtype = "string",
		optional = true
	},
}

require "common"
terminal = require "ansiterminal"
terminal.enable_color(true)

-- Argument notification callback
function on_set_arg(name, val)
	if name == "disable_color" and val == "disable_color" then
		terminal.enable_color(false)
	end

	return true
end

-- Initialization callback
function on_init()
	-- Request the fields that we need
	fbuf = chisel.request_field("evt.rawarg.data")
	fisread = chisel.request_field("evt.is_io_read")
	fres = chisel.request_field("evt.rawarg.res")
	fname = chisel.request_field("fd.name")
	fpname = chisel.request_field("proc.name")
	fcontainername = chisel.request_field("container.name")
	fcontainerid = chisel.request_field("container.id")

	-- The -pc or -pcontainer options was supplied on the cmd line
	print_container = sysdig.is_print_container_data()

	-- increase the snaplen so we capture more of the conversation
	sysdig.set_snaplen(2000)
	
	-- set the filter
	chisel.set_filter("evt.is_io=true and evt.dir=< and evt.rawres>0")
	chisel.set_event_formatter("%evt.arg.data")
	
	return true
end

-- Event parsing callback
function on_event()
	local buf = evt.field(fbuf)
	local isread = evt.field(fisread)
	local res = evt.field(fres)
	local name = evt.field(fname)
	local pname = evt.field(fpname)
	local containername = evt.field(fcontainername)
	local containerid = evt.field(fcontainerid)


	if name == nil then
		name = "<NA>"
	end

	if res <= 0 then
		return true
	end

	local container = ""
	if print_container then
		if containername == "host" then
			-- Make host green
			container = string.format("%s [%s] [%s]", terminal.green, containername, containerid );
		else
			-- Make container cyan
			container = string.format("%s [%s] [%s]", terminal.cyan, containername, containerid );
		end
	end

	if isread then
		-- Because container info might be colored make the end of the line the same color as read (red)
		name_pname = string.format("%s %s (%s)", terminal.red, name, pname );
		-- When a read occurs show it in red
		infostr = string.format("%s------ Read %s from %s %s", terminal.red, format_bytes(res), container, name_pname)
	else
		-- Because container info might be colored make the end of the line the same color as write (blue)
		name_pname = string.format("%s %s (%s)", terminal.blue, name, pname );
		-- When a write  occurs show it in blue
		infostr = string.format("%s------ Write %s to %s %s", terminal.blue, format_bytes(res), container, name_pname)
	end

	-- Print out the line (if -pc or -pcontainer sandwitch container color between either red of blue)
	print(infostr)

	return true
end

-- Called by the engine at the end of the capture (Ctrl-C)
function on_capture_end()
	print(terminal.reset)
end
