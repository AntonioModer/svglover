--[[

svglover
 Library to import and display simple SVGs in LÖVE.
 https://github.com/globalcitizen/svglover

--]]

svglover_onscreen_svgs = {}

-- load an svg and return it as a slightly marked up table
--  markup includes resolution detection
function svglover_load(svgfile)
	-- validate input
	--  file exists?
	local fh = io.open(svgfile, "r")
	if not fh then
		print("FATAL: file does not exist: '" .. svgfile .. "'")
		os.exit()
	end
	--  file is a roughly sane size?
	local size = fh:seek("end")
      	fh:seek("set", current)
	if size == nil or size < 10 or size > 500000 then
		print("FATAL: file is not an expected size (0-500000 bytes): '" .. svgfile .. "'")
		os.exit()
	end

	-- initialize return structure
	local svg = {height=0,height=0,drawcommands=''}

	-- process input
	--  - first we read the whole file in to a string
	local file_contents=''
	for line in love.filesystem.lines(svgfile) do
        	if not (line==nil) then
			file_contents = file_contents .. line
		end
  	end
	--  - remove all newlines
	file_contents = string.gsub(file_contents,"\n","")
	--  - insert newline after all tags
	file_contents = string.gsub(file_contents,">",">\n")
	--  - flush blank lines
	file_contents = string.gsub(file_contents,"\n+","\n")		-- remove multiple newlines
	file_contents = string.gsub(file_contents,"\n$","")		-- remove trailing newline
	--  - extract height and width
	svg.width = string.match(file_contents,"<svg [^>]+width=\"([0-9.]+)")
	svg.height = string.match(file_contents,"<svg [^>]+height=\"([0-9.]+)")
	--  - finally, loop over lines, appending to svg.drawcommands
	for line in string.gmatch(file_contents, "[^\n]+") do
		-- parse it
  		svg.drawcommands = svg.drawcommands .. "\n" .. __svglover_lineparse(line)
	end

	-- remove duplicate newlines
	svg.drawcommands = string.gsub(svg.drawcommands,"\n+","\n")
	svg.drawcommands = string.gsub(svg.drawcommands,"^\n","")
	svg.drawcommands = string.gsub(svg.drawcommands,"\n$","")

	-- return
	return svg
end

-- place a loaded svg in a given screen region
function svglover_display(svg,x,y,region_width,region_height,leave_no_edges,border_color,border_width)
	-- handle arguments
	region_width = region_width or math.min(love.graphics.getWidth-x,svg.width)
	region_height = region_height or math.min(love.graphics.getHeight-y,svg.height)
	leave_no_edges = leave_no_edges or true
	border_color = border_color or nil
	border_width = border_width or 1
	-- validate arguments
	if svg.width == nil or svg.height == nil or svg.drawcommands == nil then
		print("FATAL: passed invalid svg object")
		os.exit()
	elseif region_width < 1 or region_width > 10000 then
		print("FATAL: passed invalid region_width")
		os.exit()
	elseif region_height < 1 or region_height > 10000 then
		print("FATAL: passed invalid region_height")
		os.exit()
	elseif leave_no_edges ~= false and leave_no_edges ~= true then
		print("FATAL: passed invalid leave_no_edges")
		os.exit()
	elseif border_color ~= nil then
		for element in pairs(border_color) do
			if element < 0 or element > 255 or element == nil then
				print("FATAL: passed invalid border_color")
				os.exit()
			end
		end
	elseif border_width < 1 or border_width > 10000 then
		print("FATAL: passed invalid border_width")
		os.exit()
	end

	-- calculate drawing parameters
        --  - determine per-axis scaling
        local scale_factor_x = region_width  / svg.width
        local scale_factor_y = region_height / svg.height

        --  - select final scale factor
        --  if we use the minimum of the two axes, we get a blank edge
        --  if we use the maximum of the two axes, we lose a bit of the image
        local scale_factor = math.max(scale_factor_x,scale_factor_y)

	--  - centering offsets
	local centering_offset_x = 0
	local centering_offset_y = 0
        if scale_factor * svg.width > region_width then
                centering_offset_x = -math.floor(((scale_factor*svg.width)-region_width)*0.5)
        elseif scale_factor * svg.height > region_height then
                centering_offset_y = -math.floor(((scale_factor*svg.height)-region_height)*0.5)
        end

	-- remember the determined properties
	svg['region_origin_x'] = x
	svg['region_origin_y'] = y
	svg['cx'] = centering_offset_x
	svg['cy'] = centering_offset_y
	svg['sfx'] = scale_factor
	svg['sfy'] = scale_factor
	svg['region_width'] = region_width
	svg['region_height'] = region_height
	svg['border_color'] = border_color
	svg['border_width'] = border_width

	-- draw
	return table.insert(svglover_onscreen_svgs,__svglover_dc(svg))
end

-- actually draw any svgs that are scheduled to be on screen
function svglover_draw()
	-- loop through on-screen SVGs
	for i,svg in ipairs(svglover_onscreen_svgs) do
		-- bounding box
		if svg.border_color ~= nil then
			love.graphics.setColor(svg.border_color)
			love.graphics.rectangle('fill',svg.region_origin_x-svg.border_width, svg.region_origin_y-svg.border_width, svg.region_width+svg.border_width*2, svg.region_height+svg.border_width*2)
			love.graphics.setColor(0,0,0,255)
			love.graphics.rectangle('fill',svg.region_origin_x, svg.region_origin_y, svg.region_width, svg.region_height)
		end
		-- push graphics settings
		love.graphics.push()
		-- clip to the target region
	        love.graphics.setScissor(svg.region_origin_x, svg.region_origin_y, svg.region_width, svg.region_height)
	        -- draw in the target region
	        love.graphics.translate(svg.region_origin_x+svg.cx, svg.region_origin_y+svg.cy)
	        -- scale to the target region
	        love.graphics.scale(svg.sfx, svg.sfy)
		-- draw
		assert (loadstring (svg.drawcommands)) ()
	        -- disable clipping
	        love.graphics.setScissor()
		-- reset graphics
		love.graphics.pop()
	end
end


-- parse an input line from an SVG, returning the equivalent LOVE code
function __svglover_lineparse(line)

	-- rectangle
	if string.match(line,'<rect ') then
                -- SVG example:
                --   <rect x="0" y="0" width="1024" height="680" fill="#79746f" />
		--   <rect fill="#1f1000" fill-opacity="0.501961" x="-0.5" y="-0.5" width="1" height="1" /></g>
                -- lua example:
                --   love.graphics.setColor( red, green, blue, alpha )
                --   love.graphics.rectangle( "fill", x, y, width, height, rx, ry, segments )

                -- now, we get the parts

                --  x (x_offset)
                x_offset = string.match(line," x=\"([^\"]+)\"")

                --  y (y_offset)
                y_offset = string.match(line," y=\"([^\"]+)\"")

                --  width (width)
                width = string.match(line," width=\"([^\"]+)\"")

                -- height (height)
                height = string.match(line," height=\"([^\"]+)\"")

                --  fill (red/green/blue)
                red, green, blue = string.match(line,"fill=\"#(..)(..)(..)\"")
                red = tonumber(red,16)
                green = tonumber(green,16)
                blue = tonumber(blue,16)

                --  fill-opacity (alpha)
                alpha = string.match(line,"opacity=\"([^\"]+)\"")
		if alpha == nil then
			alpha = 255
		else
                	alpha = math.floor(255*tonumber(alpha,10))
		end

                -- output
		result = "love.graphics.setColor(" .. red .. "," .. green .. "," .. blue .. "," .. alpha .. ")\n"
                result = result .. "love.graphics.rectangle(\"fill\"," .. x_offset .. "," .. y_offset .. "," .. width .. "," .. height .. ")\n"
		return result

	-- ellipse or circle
	elseif string.match(line,'<ellipse ') or string.match(line,'<circle ') then
                -- SVG example:
                --   <ellipse fill="#ffffff" fill-opacity="0.501961" cx="81" cy="16" rx="255" ry="22" />
		--   <circle cx="114.279" cy="10.335" r="10"/>
                -- lua example:
                --   love.graphics.setColor( red, green, blue, alpha )
                --   love.graphics.ellipse( mode, x, y, radiusx, radiusy, segments )

		-- get parts
                --  cx (center_x)
                center_x = string.match(line," cx=\"([^\"]+)\"")

                --  cy (center_y)
                center_y = string.match(line," cy=\"([^\"]+)\"")

                --  r (radius, for a circle)
                radius = string.match(line," r=\"([^\"]+)\"")

		if radius ~= nil then
			radius_x = radius
			radius_y = radius
		else
                	--  rx (radius_x, for an ellipse)
                	radius_x = string.match(line," rx=\"([^\"]+)\"")

                	--  ry (radius_y, for an ellipse)
                	radius_y = string.match(line," ry=\"([^\"]+)\"")
		end

                --  fill (red/green/blue)
                red, green, blue = string.match(line,"fill=\"#(..)(..)(..)\"")
		if red ~= nil then
                	red = tonumber(red,16)
                	green = tonumber(green,16)
                	blue = tonumber(blue,16)
		end

                --  fill-opacity (alpha)
                alpha = string.match(line,"opacity=\"(.-)\"")
		if alpha ~= nil then
                	alpha = math.floor(255*tonumber(alpha,10))
		end

                -- output
                local result = ''
		if red ~= nil then
			result = result .. "love.graphics.setColor(" .. red .. "," .. green .. "," .. blue .. "," .. alpha .. ")\n";
		end
                result = result .. "love.graphics.ellipse(\"fill\"," .. center_x .. "," .. center_y .. "," .. radius_x .. "," .. radius_y .. ",50)\n";
		return result

	-- polygon (eg. triangle)
	elseif string.match(line,'<polygon ') then
                -- SVG example:
                --   <polygon fill="--6f614e" fill-opacity="0.501961" points="191,131 119,10 35,29" />
                -- lua example:
                --   love.graphics.setColor( red, green, blue, alpha )
                --   love.graphics.polygon( mode, vertices )   -- where vertices is a list of x,y,x,y...

                --  fill (red/green/blue)
                red, green, blue = string.match(line,"fill=\"#(..)(..)(..)\"")
                red = tonumber(red,16)
                green = tonumber(green,16)
                blue = tonumber(blue,16)

                --  fill-opacity (alpha)
                alpha = string.match(line,"opacity=\"(.-)\"")
                alpha = math.floor(255*tonumber(alpha,10))

                --  points (vertices)
                vertices = string.match(line," points=\"([^\"]+)\"")
                vertices = string.gsub(vertices,' ',',')

                -- output
                --   love.graphics.setColor( red, green, blue, alpha )
		local result = "love.graphics.setColor(" .. red .. "," .. green .. "," .. blue .. "," .. alpha .. ")\n"
                --   love.graphics.polygon( mode, vertices )   -- where vertices is a list of x,y,x,y...
                result = result .. "love.graphics.polygon(\"fill\",{" .. vertices .. "})\n";
		return result

	-- start or end svg etc.
	elseif  string.match(line,'</?svg') or 
		string.match(line,'<.xml') or 
		string.match(line,'<!--') or 
		string.match(line,'</?title') or
		string.match(line,'<!DOCTYPE') then
		-- ignore

	-- end group
	elseif string.match(line,'</g>') then
		return 'love.graphics.pop()'

	-- start group
	elseif string.match(line,'<g[> ]') then
                --  SVG example:
                --    <g transform="translate(226 107) rotate(307) scale(3 11)">
		--    <g transform="scale(4.000000) translate(0.5 0.5)">
                --  lua example:
                --    love.graphics.push()
                --    love.graphics.translate( dx, dy )
                --    love.graphics.rotate( angle )
                --    love.graphics.scale( sx, sy )
		local result = "love.graphics.push()\n"
                -- extract the goodies
                --  translation offset
                offset_x,offset_y = string.match(line,"[ \"]translate.([^) ]+) ([^) ]+)")
                --  rotation angle
                angle = string.match(line,"rotate.([^)]+)")
		if angle ~= nil then
                	angle = angle * 3.14159/180	-- convert degrees to radians
		end
                --  scale
		--   in erorr producing: love.graphics.scale(73 103,73 103)  ... from "scale(3 11)"
		scale_x = 1
		scale_y = 1
                scale_string = string.match(line,"scale.([^)]+)")
		if scale_string ~= nil then
			scale_x,scale_y = string.match(scale_string,"([^ ]+) ([^ ]+)")
			if scale_x == nil then
				scale_x = scale_string
				scale_y = nil
			end
		end

                -- output
		if offset_x ~= nil and offset_y ~= nil then
                	result = result .. "love.graphics.translate(" .. offset_x .. "," .. offset_y .. ")\n"
		end
                if angle ~= nil then
                        result = result .. "love.graphics.rotate(" .. angle .. ")\n"
                end
                if scale_y ~= nil then
                        result = result .. "love.graphics.scale(" .. scale_x .. "," .. scale_y .. ")\n";
                elseif scale_x ~= nil then
                        result = result .. "love.graphics.scale(" .. scale_x .. "," .. scale_x .. ")\n";
                end
		return result
	else
		-- display issues so that those motivated to hack can do so ;)
		print("LINE '" .. line .. "' is unparseable!")
		os.exit()
	end
	return ''
end

-- deep copy
function __svglover_dc(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[__svglover_dc(orig_key)] = __svglover_dc(orig_value)
        end
        setmetatable(copy, __svglover_dc(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end
