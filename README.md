# svglover

A library to import and display simple SVGs in [LÖVE](http://love2d.org/).

Note that because it is specifically written for LÖVE, it is probably not useful for other [Lua](http://www.lua.org/) environments.

The latest code can always be found at [Github](https://github.com/globalcitizen/svglover).

## Status

The library is not yet functional.

## Usage

You should normally load your SVGs straight away in the `love.load()` function to prevent duplicate reads, as follows:

```
pic = svglover_load('some.svg')
```

You then specify where you want them displayed using `svglover_display(image,topleft_x,topleft_y,width,height,fill_region,border_color,border_width)` where `fill_region`, `border_color` and `border_width` are optional.

Finally, you should add the `svglover_draw()` call to the end of your `love.draw()` function.

A complete example is therefore as follows.

```
function love.load()
        pic = svglover_load('some.svg')
        svglover_display(pic,100,100,100,100,true,{255,0,0,255},1)
end

function love.draw()
        -- draw any scheduled SVGs
        svglover_draw()
end
```

## Motivation

I wanted to place images in a roguelike game I was making, [Zomia](https://github.com/globalcitizen/zomia), but there was no pre-existing library. I first built [a proof of concept in perl, svg2love](https://github.com/globalcitizen/svg2love), but then wanted to load files direct from SVG in Lua instead of an intermediate format.

This is my first Lua library, so it probably ignores many best practices.
