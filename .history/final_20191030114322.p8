pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
lives = 0
camerax = -128
music_on = false
player = {
	x = 8,
	y = 0,
	w = 3,
	h = 6,
	sx = 2,
	sy = 0,
	can_move = true,
	grounded = false,
	accel = 0,
	maxaceel = 2.5,
	speed = 0.70,
	sprite = 1,
	flip_sprite_x = false,
	jump_hold = 0
}
hard_mode = false
bads = {}
projectiles = {}
flag_x = 0
flag_max_y = 0
level_end = false
update_fuc = nil
draw_func = nil

function _update60()
    update_func()
end

function _draw()
    draw_func()
end

function update_char_select()
    if btn(0) or btn(1) then 
        hard_mode = not hard_mode
    end
    if hard_mode then
        player.sprite = 1
    else
        player.sprite = 19
    end
end

function draw_char_select()
    spr(player.sprite, player.x, player.y, 1, 1, player.flip_sprite_x)
end

function goomba(x,y,speed,s_num)
    local g = {}
    g.x = x*8
    g.y = y*8
    g.o_x = x*8
    g.o_y = y*8
    g.w = 5
    g.h = 5
    g.sx = 1
    g.sy = 2
    g.accel = 0
    g.speed = speed
    g.s_num = s_num
    g.show = true
    return g
end

function move_opposition()
    for g in all(bads) do
        if g.show then
            local move = g.speed
            if check_move(g.x + g.sx + move, g.y + g.sy, g.w, g.h) then
                g.speed = -g.speed
            else
                g.x += move
            end

            local accel = g.accel
        
            if not check_move(g.x + g.sx, g.y + g.sy + accel, g.w, g.h) then
                g.y += accel
            else
                g.accel = 0
            end
            
            g.accel += 0.15
            
            if g.accel > 1.5 then
            g.accel = 1.5
            end

            check_player_collision(g)
        end
    end
end

function check_player_collision(goomba)
    local p_top = flr(player.y + player.sy)
    local p_bot = flr(p_top + player.h)
    local p_left = flr(player.x + player.sx)
    local p_right = flr(p_left + player.w)
    local g_top = flr(goomba.y + goomba.sy)
    local g_bot = flr(g_top + goomba.h)
    local g_left = flr(goomba.x + goomba.sx)
    local g_right = flr(g_left + goomba.w)
    if (p_bot >= g_top and p_bot < g_top + (goomba.h*.2)) and 
    ((p_left >= g_left and p_left <= g_right) or
    (p_right >= g_left and p_right <= g_right))
    and not player.grounded then
        player.accel = -1
        goomba.show = false
        return
    end
    if ((p_bot >= g_top and p_bot <= g_bot) or
    (p_top >= g_top and p_top <= g_bot)) and 
    ((p_left >= g_left and p_left <= g_right) or
    (p_right >= g_left and p_right <= g_right)) then
        lives-=1
        player.x = 8
        player.y = 0
        reset()
    end
end

function draw_bads()
    for g in all(bads) do
        if g.show then
            spr(g.s_num, g.x, g.y)
        end
    end
end

function _init()
    draw_func = draw_char_select
    update_func = update_char_select
    music(0)
    lives = 3
    local index = 0
    for i=0,127 do
        for j=0,16 do
            local sprite = mget(i,j)
            if fget(sprite,7) then
                add(bads,goomba(i,j,.5,sprite))
                mset(i,j,64)
            end
            if fget(sprite, 4) then
                flag_x = i*8 + 5
                flag_max_y = j*8 + 5
            end
        end
    end
end

function reset()
    camerax = -128
    for g in all(bads) do
        g.x = g.o_x
        g.y = g.o_y
        g.show = true
        g.speed = .5
    end
	projectiles = {}
end

function gravity()
    local dy = player.accel
    
	local x = player.x + player.sx
	local y = player.y + player.sy + dy
    if not check_move(x, y, player.w, player.h) then
		-- not inside a block
        player.y += dy
        player.grounded = false
    else
		-- check if they are not inside the roof, thus they are inside the ground
		if not (check_flag(x, y) or check_flag(x + player.w, y)) then
			player.grounded = true
		end
		player.accel = 0
		player.jump_hold = 0
    end
    
    player.accel += 0.15
    
    if player.accel > player.maxaceel then
      player.accel = player.maxaceel
    end
end

function update_game()

    local dx = 0
    gravity()
	
    if btn(0) then
        dx = -player.speed
		player.flip_sprite_x = true
    end
    if btn(1) then
        dx = player.speed
		player.flip_sprite_x = false
    end
	
	if btn(2) then
		if player.grounded then
			player.accel = -1.3
			player.grounded = false
			player.jump_hold = 1
		end
		if player.jump_hold > 0 and player.jump_hold <= 40 then
			player.accel += (-0.55 / (player.jump_hold))
			player.jump_hold += 1
		end
	elseif player.jump_hold > 0 then
		player.jump_hold = 0
	end
	
	local new_pos = {
		x = player.x + player.sx + dx,
		y = player.y + player.sy
	}
	
    player.can_move = not check_move(new_pos.x, new_pos.y, player.w, player.h)
    if check_end(new_pos.x, new_pos.y, player.w, player.h) then
        
    end
    if player.can_move and player.x + dx > camerax then
        player.x += dx
    end
	
	if btnp(5) then
		-- projectiles
		shoot_projectile(player.x, player.y, player.flip_sprite_x)
	end
	
    check_death()
    move_opposition()
	move_projectiles()
end

function shoot_projectile(x, y, flp)
    sfx(40, 1)
	local p = {
		spr = 2,
		x = x,
		y = y,
		sx = 0,
		sy = 1,
		w = 7,
		h = 5,
		flp = flp
	}
	add(projectiles, p)
end

function move_projectiles()
	for p in all(projectiles) do
		local dx = (p.flp and -2 or 2)
		-- check collision with map or outside of map
		if p.x + p.w < camerax or 
		   p.x - p.w > 1024 or
		   check_move(p.x + p.sx + dx, p.y + p.sy, p.w, p.h) then
			del(projectiles, p)
		else
			-- check sprite collision
			for g in all(bads) do
				if g.show then
					local collide = check_sprite_collision(p.x, p.y, p.sx, p.sy, p.w, p.h, g.x, g.y, g.sx, g.sy, g.w, g.h)
					if collide then
						del(projectiles, p)
						-- kill goomba
						g.show = false
						return
					end
				end
			end
			
			p.x += dx
		end
	end
end

--[[
	Check if the two sprites are inside one another.
	x1 - x position of sprite 1
	y1 - y position of sprite 1
	sx1 - starting x of sprite 1
	sy1 - starting y of sprite 1
	w1 - width of sprite 1, '0' denotes that the width is 1 pixel
	h1 - height of sprite 1, '0' denotes that the height is 1 pixel
--]]
function check_sprite_collision(x1, y1, sx1, sy1, w1, h1, x2, y2, sx2, sy2, w2, h2)
	local spr1_x = x1 + sx1
	local spr1_y = y1 + sy1
	local spr2_x = x2 + sx2
	local spr2_y = y2 + sy2
	return abs(spr1_x - spr2_x) * 2 <= w1 + w2 + 1 and
	       abs(spr1_y - spr2_y) * 2 <= h1 + h2 + 1
end

function draw_projectiles()
	for p in all(projectiles) do
		spr(p.spr, p.x, p.y, 1, 1, p.flp)
	end
end

function check_end(x,y,w,h)
    return check_move(x,y,w,h,3)
end 

function check_death()
    if player.y > 120 then
        lives-=1
        player.x = 8
        player.y = 0
        reset()
    end
end

function check_move(x,y,w,h,f)
    f = f or 0
    return check_flag(x+w, y, f) or
            check_flag(x, y+h, f) or
            check_flag(x, y, f) or
            check_flag(x+w, y+h, f)
end

function check_flag(x, y, f)
    return fget(mget(x/8,y/8),f)
end

function draw_game()
    if lives > 0 then
        if player.x - 60 > camerax then
            camerax = player.x - 60
        end
        -- cameray = player.y - 60
        cameray = 0
        camera(camerax, cameray)
        cls(5)
        map(0,0,0,0,128,16)
        draw_bads()
		draw_projectiles()
        spr(player.sprite, player.x, player.y, 1, 1, player.flip_sprite_x)
        print("lives: ",camerax,cameray,7)
        for i=1,lives do
            spr(3, camerax + 18 + (4*i), cameray-1)
        end
    else
        player.x = 0
        player.y = 0
        camera(0,0)
        cls()
        print("game ♥ over!!!",35,60,2)
    end
end
__gfx__
00000000007777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007777000000990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070000fff5000999944000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000007775009aaa444f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000077750009aa4f4400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700007777000999944000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007777000000990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888a88000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
888859a8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8885499a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88588445000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
85282885000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
58888885000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
85888858000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88555588000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
888888885666666555555655555556898a88a8886555555665555556655555560888888888888888888888000000000000000000000000000000000000000000
88888888656666566555555569555589889a9a8a5655556556555565565555650008888888888888888880090000000000000000000000000000000000000000
88888888665665665555555559555555a999999a5565565555655655556556559900088888888888888000990000000000000000000000000000000000000000
8888888866655666565655565656895688a999a8555665555550055555566555a9a9000888000888800099a80000000000000000000000000000000000000000
88888888666556665555555555558955a999999a555665555550055555566555a989990088099080009a9aa80000000000000000000000000000000000000000
888888886656656655555556555895568a9999aa556556555565565555655655888aa99a0009a00999a8aa880000000000000000000000000000000000000000
8888888865666656565565558655655588a999a856555565565555655655556588888a980999899aaa888a880000000000000000000000000000000000000000
8888888856666665555555558955555588a99a886555555665555556000000008888a9889aa88aa8888888880000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010101000101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
40404040404040404040484a4040404040404040404040404049404040484a4040404040404040404040404040404040404040494040404040484a40404040404040404040404040404040404040404040404040404040484a404040404040404040404040404040404040404040404040404040404940404040404040404040
404040484a40404040404040404040404040404040404040404040404040404040404040404040404040484a4040404040404040404040404040404040404040404040484a404040404040404040404040404040404040404040404049404040404040404049404040404040404040404040404040404040404040404040484a
40404040484a40404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040484a404040404040404041414140414141404040404040484a404040404040
40404040404040404040404940404040404040404040484a404040404040404040484a4040404040404040404040404040484a4040404040404040404040404040404040404040404040404040404040484a40404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040484a404040404040404040404040494040404040404040404940404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404141414040404040484a4040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040484a40404040494040404040404040404040404040404940404040404040404040404040404040404040404040404040404040404040404040404040404040404040404545
4040404040404140414041404040404041404040494040404040404040404140404040404140404040404040404040414041404140404040404040404040404040404040404040404040404141414040404040404040404040404040414041404140404040414141404040404040404040404040404040414040494040404545
4040494040404040404040404040404040404040404040404040404040414140404040404040404040404040404040404040404040404040404040404040404040404041404041404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404041414040404040404546
4040404040404040404040404040404040404040404040404040404041414140404040404040444040404040404440404040404040444444404040404040404040404141401041414040404040404040444040404040404040404440404040404040404440404040404040404044404040404040404141414040104010404747
4242424242424242424342424243424242424242424342404042424243424242424243424242424342404042424342424242424242434242424242404042434242424242434242424242424342424242434242424040434242424243424242424243424242434242424243424242434242424040424342424243424242424242
4242424342424342424242424242424243424243424242444443424242424342424242424243424242444443424242424342424243424242424342444442424242434242424243424242424242434242424243424444424243424242424243424342424242424243424242424242424242434444424242434242424242434242
__sfx__
001000002850022500295502a55029550285501950026550155002555024550275002355021550205501d5501c5500e5000e50000500005000050000500005000050000500005000050000500005000050000500
00100020220100e0100c0100c0500c0500d050180501a0501c0501d0501f05021050230502a050320502c0501205014050160500c0500e0501005011050130501505017050190501b050190501b0501e05020050
001000000c5400c54004540155401f54016540115400f5400f540145401d540205401c540165400e540075400f540165401d54023540275402954027540215401b54012540105400c5400c5400a5400c5400a540
00200000106100f6100e6100d6100c61012610186101e6102261024610226101f6101c61019610156100f6100c61009610076100a6100e610116101461016610186101a6101761015610136100e6100a61009610
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000365000600006000060000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
02 02424343

