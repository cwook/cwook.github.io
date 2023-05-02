-- by default, scripts only run in Play mode
-- to make them run in other modes, or disable play mode, do this:
-- runmode_play = false < disables running in play mode
-- runmode_edit = true < enables running in edit mode
-- runmode_pause = true < enables running in pause mode


-- this automatically adds an association between the GameObject this script is attached to and the Enemy prefab
-- TODO remove this as it's only an editor concern
go.prefab = "Enemy.prefab"

-- MICHEAL: colors are stored red, green, blue, alpha from 0 to 1
-- color of the light when the enemy catches the player
color_caught =  vector4.new(1.000, 0.147, 0.007, 1)
-- color of the light when the enemy is patrolling etc.
color_regular = vector4.new(0.659, 0.698, 0.000, 1)
color_target = color_regular

-- script_values are loaded and displayed in the editor
script_values =
{
    chase_speed = 8,
    speed = 4,
    turn_speed = 50,
    path_list = "",
    pathing_mode = "static",
    search_time = 8,
    path_stop_time = 1.5,
    aud_camera_alarm = "CameraAlarm",
    health = 100,

    alerted_tolerance = 2.0,
    alert_amount_while_in_trigger = 2.0,
    alert_lost_per_second = 1,
  
    look_at_player = true,
    
    tex_drone = "Drone"

    
    --[[
    anim_walk_side = "ACSideRun",
    anim_walk_up = "ACFrontRun",
    anim_walk_down = "ACBackRun",
    anim_idle_side = "ACSideIdle",
    anim_die = "PCSideCaught"
    ]]
}
script_values_tooltips =
{
    chase_speed = "How fast the enemy moves when chasing.",
    speed = "How fast the enemy moves while patrolling or searching",
    pathing_mode = "\"static\" - no movement\n\"loop\" - follows the path in a loop\n\"back_and_forth\" - follows the path back_and_forth",
    turn_speed = "The rotation speed of the enemy, in degrees per second.",
    path_list = "A comma-separated list of unique GameObject names representing a path. No spaces.",
    search_time = "How many seconds to search when distracted by a Beacon",
    path_stop_time = "How long to stop at each patrol node or search position",
    aud_camera_alarm = "Camera Alarm Sound",
    aud_death = "Death Music",
    alerted_tolerance = "the threshhold at which enemy becomes alerted",
    alert_amount_while_in_trigger = "a value to add per second to this enemies alert level when standing inside the veiw cone",
    alert_lost_per_second = "the amount of alert to lose every second"
  
}

-- declaring global variables that will be used in this script
path = {}
path_index = 0
path_length = 0
path_advance_dir = 1 -- for back-and-forth paths
path_dist = 1000000
path_stopping_dist = 0.5
path_stop_timer = script_values.path_stop_time

state = "idle"
chase_target = nil

search_timer = 0

--audio purposes
aud_alarm_cooldown = 0

--How Alerted an enemey is
alert_level = 0.0
player_in_trigger = false
player_in_trigger_last_frame = false


player = nil

-- helper function, convert degrees to radians
function deg2rad(degrees)
    return (degrees * math.pi) / 180
end

-- helper function, convert radians to degrees
function rad2deg(radians)
    return (180 * radians) / math.pi
end

-- helper function
function lerp(a, b, t)
    return a * (1 - t) + b * t
end

-- help function, rotates on degree value towards another direction
function rotate_towards_degrees(from, to, amount)
    from = math.fmod(from + 360, 360)
    to = math.fmod(to + 360, 360)
    diff = from - to
    if from > to then
        amount = amount * -1
    end
    if math.abs(diff) < math.abs(amount) then
        return to
    elseif math.abs(diff) < 180 then
        return from + amount
    else
        return from - amount
    end
end

-- will be called by Beacon.lua to distract enemies
function distract(self, position)
    if state == "idle" then
        state = "search"
        path["search"] = {}
        path["search"][0] = vector2.new(position.x, position.y)
        search_timer = script_values.search_time
        path_dist = 1000000
        path["search"][1] = math.atan( (position.y - transform.position.y) / (position.x - transform.position.x) ) - 90

        for k, v in pairs(path["search"]) do
            print("k: " .. tostring(k) .. ", v: " .. tostring(v))
        end
    end
end

-- init function, called when the UpdateMode changes (ie when scene is played)
function init()
    
    light_angleInner_initial = light.angleInner
    light_angleOuter_initial = light.angleOuter

    transform.rotation = transform.rotation
    local i = 0 -- tracks path length
    
    if script_values.pathing_mode ~= "static" then
        local path_temp = script_values.path_list
        -- remove whitespace - this is not perfect and only works if there's no whitespace before the list of points
        --path_temp = path_temp:sub(0, path_temp:find(" ") - 1)

        while path_temp:len() > 0 do
            -- find the first comma
            local next_pt = path_temp:find(",")
            if next_pt == nil then
                -- we are on the last point
                next_pt = path_temp:len() + 1
            end
            local gname = path_temp:sub( 0, next_pt - 1 )
            -- find GameObject by name - path objects must have unique names!
            local g = objectmanager:findGameObject( gname )
            if type(g) == "userdata" then
                -- add to path
                path[i] = g
                i = i + 1
            end
            -- trim path_temp
            path_temp = path_temp:sub( next_pt + 1)
        end

        -- save path length
        path_length = i
        -- reset path_index
        path_index = 0

        if script_values.pathing_mode == "loop" then
            path_advance_dir = 1
        end
    end

    if #path == 0 then
        
        script_values.pathing_mode = "static"
        
        path_advance_dir = 1
        -- save the spawn location for later
        path["static"] = {  }
        path["static"][0] = vector2.new(transform.position.x, transform.position.y)
        path["static"][1] = transform.rotation

    end
    
    if renderable == nil then
        renderable = go:addRenderable()
    end
    renderable:setTexture(script_values.tex_drone)

    utility:subscribe("crush")
    --How Alerted an enemey is
    alert_level = 0.0

    player = objectmanager:findGameObject("Player")
    if player == nil then
        print("Enemy couldn't find the Player! Make sure it's GameObject is named correctly.")
    end

    music_player = objectmanager:findGameObject("MusicPlayer")
    if music_player == nil then
        print("Enemy couldn't find the MusicPlayer! Make sure it's GameObject is named correctly.")
    else
        music_player_env = music_player.behavior:getBehavior("MusicPlayer.lua").env
    end
    
end


function move_towards(pos, spd, dt)
    -- caclulate the direction towards the chase_target
    local dir = vector2.new()
    dir.x = pos.x - transform.position.x
    dir.y = pos.y - transform.position.y
    local length = dir:length()
    dir.x = dir.x / length
    dir.y = dir.y / length

    -- lua math has an atan2 function but it doesn't seem to work
    local r = math.atan(dir.y, dir.x)
    -- convert to degrees
    r = math.deg(r)
    --[[
    if dir.x < 0 then
        r = r + 180 -- dunno why we need to do this
    end
    ]]
    local old_rotation = transform.rotation;
    -- rotate towards pos
    transform.rotation = rotate_towards_degrees( transform.rotation, r, dt * script_values.turn_speed * math.max(1, math.log(length)))

    -- move towards pos
    if math.abs(old_rotation - transform.rotation) < 5.0 then
      physicsbody:setVelocity( vector2.new( dir.x * spd, dir.y * spd ) )
    end

    return length
end


-- update function, called on game Update
function update(dt)


    local color_spd = 4
    if player_in_trigger == true then
        alert_level = alert_level + (dt * script_values.alert_amount_while_in_trigger)
        alert_level = math.min(alert_level, script_values.alerted_tolerance)
        color_target = color_caught
        color_spd = 24
    elseif alert_level > 0 then
        alert_level = alert_level - (dt * script_values.alert_lost_per_second)
        if alert_level < 0 then
            alert_level = 0
        end
    end

    if path_stop_timer > 0 then
        color_spd = math.max(color_spd, 10)
    end

    local t = alert_level / script_values.alerted_tolerance
    light.angleInner = lerp(light_angleInner_initial, 1, t)
    light.angleOuter = lerp(light_angleOuter_initial, light_angleOuter_initial/3, t)
    light.intensity = lerp(1.5, 2.5, t)
    
    light.diffuse = vector4.new(
        lerp( light.diffuse.x, color_target.x, dt*color_spd ),
        lerp( light.diffuse.y, color_target.y, dt*color_spd ),
        lerp( light.diffuse.z, color_target.z, dt*color_spd ), 1)
        

    --print(go.name .. " state: " .. state)
    -- if our state is chase and we have a chase_target
    
    if state == "gameover" then


    elseif state ~= "dead" and script_values.health <= 0 then
        state = "dead"
        print("Enemy dead")
        -- animation:setAnimation(script_values.anim_die)
        -- animation:setCommand("PlayOnce")

    elseif state == "chase" and chase_target ~= nil then
        
        -- chase the target
        move_towards(chase_target.transform.position, script_values.chase_speed, dt)

        --only for audio purposes
        if aud_alarm_cooldown < 0.01 then
          aud_alarm_cooldown = aud_alarm_cooldown + 0.3
        else
          aud_alarm_cooldown = aud_alarm_cooldown - dt;
        end
       
    elseif state == "search" then
        
        -- decrement search_timer
        search_timer = search_timer - dt

        -- path_stop_timer is used to make the enemy search more thoughtfully, pausing between movements
        if path_stop_timer > 0 then
            path_stop_timer = path_stop_timer - dt
            transform.rotation = rotate_towards_degrees(transform.rotation, path["search"][1], dt * script_values.turn_speed)
        else
            if path_dist > path_stopping_dist then
                path_dist = move_towards(path["search"][0], script_values.speed, dt)
            else
                -- rotate 90 degrees
                path["search"][1] = path["search"][1] + 90
                -- make the enemy wait a bit before it moves to the new spot
                path_stop_timer = script_values.path_stop_time
                -- randomize search position a little bit
                path["search"][0] = vector2.new( path["search"][0].x + (math.random() - 0.5) * 2, path["search"][0].y + (math.random() - 0.5) * 2 )
                path_dist = 1000000
            end
        end

        -- stop searching and go back to what we were doing before
        if search_timer <= 0 then
            path_stop_timer = 0
            state = "idle"
        end

    elseif state == "idle" then
    
        if player_in_trigger and script_values.look_at_player then
            
            -- rotate towards player
            move_towards(player.transform.position, 0, dt)
            
        end

        if alert_level <= 0.25 then
            -- normal behavior: static or patrolling
            -- if we aren't already at our target
            if path_dist > path_stopping_dist then
            
                if script_values.pathing_mode == "static" then
                    -- if we're static, move back to our spawn position
                    path_dist = move_towards(path["static"][0], script_values.speed, dt)
                else
                    -- otherwise move towards the next object in the path
                    path_dist = move_towards(path[path_index].transform.position, script_values.speed, dt)
                end
                
            elseif path_stop_timer > 0 then
            
                if script_values.pathing_mode ~= "static" then
                    transform.rotation = rotate_towards_degrees(transform.rotation, path[path_index].transform.rotation, script_values.turn_speed * dt)
                else
                    transform.rotation = rotate_towards_degrees(transform.rotation, path["static"][1], script_values.turn_speed * dt)
                end
                
                if math.abs(diff) <= 5 then
                    path_stop_timer = path_stop_timer - dt
                end

                if script_values.pathing_mode ~= "static" then
                    if path_stop_timer <= 0.0 then
                        color_target = color_regular
                    elseif path_stop_timer < 0.1 then
                        color_target= vector4.new(0)
                    elseif path_stop_timer < 0.2 then
                        color_target = color_regular
                    elseif path_stop_timer < 0.3 then
                        color_target= vector4.new(0)
                    elseif path_stop_timer < 0.4 then
                        color_target = color_regular
                    elseif path_stop_timer < 0.5 then
                        color_target= vector4.new(0)
                    end
                end
            end
            
            if path_dist <= path_stopping_dist and path_stop_timer <= 0 then

                -- make the enemy wait a bit before it moves to the new spot
                path_stop_timer = script_values.path_stop_time

                --print("path_index: " .. path_index)
                if script_values.pathing_mode == "back_and_forth" then
                    -- back-and-forth path movement, will reverse direction at the end of a path and go back
                    path_index = path_index + path_advance_dir
                    if path_index >= path_length then
                        path_advance_dir = -1
                        path_index = math.max(0, path_length - 2)
                    elseif path_index <= -1 then
                        path_advance_dir = 1
                        path_index = math.min(1, path_length - 1)
                    end
                    
                elseif script_values.pathing_mode == "loop" then
                    -- regular looped movement
                    path_index = (path_index + 1) % path_length
                end
                
                path_dist = 1000000
            end

        end
    end

    if player ~= nil then
        local distance = player.transform.position:distance(transform.position)
        local t = 1 - (distance / 8)^2
        if distance < 8 then
            music_player_env:set_threat_level(t)
        end
    end
    
end

-- late_update function, called on game LateUpdate
function late_update(dt)

end

function raycast_player(p)
    local exclusion = { go, p }
    local collided = utility:rayCast( 
        vector2.new(transform.position.x, transform.position.y), 
        vector2.new(p.transform.position.x, p.transform.position.y), 
        exclusion)
    return (collided == false)
end

-- if the gameobject that this behavior is on has a ColliderComponent with trigger enabled, this function will be called
-- when something enters the trigger
function on_trigger_enter(col)
    -- col.first_object is the first gameobject in a collision, for triggers this is always the trigger
    -- col.second_object is the second gameobject in a collision, for triggers this is always what entered the trigger
    -- in Lua we have access to some GameObject 
    if (col.second_object.name == "Player") then
        if false == col.second_object.behavior:getBehavior("Player.lua").env.invisible then
            if raycast_player(col.second_object) then
                player_in_trigger = true
            else
                player_in_trigger = false
            end
        else
            player_in_trigger = false
        end
    end
end

function on_trigger_stay(col)
    
    if (col.second_object.name == "Player") then

        if false == col.second_object.behavior:getBehavior("Player.lua").env.invisible then
            
            if raycast_player(col.second_object) then
                --Increases alert level until alerted
                player_in_trigger = true 
                if alert_level >= script_values.alerted_tolerance then
                    state = "chase"
                    path_dist = 1000000
                    chase_target = col.second_object
                    player = chase_target
                end

                if player_in_trigger_last_frame == false and particle_emitter0 ~= nil then
                    particle_emitter0:emitInstant()
                    player_in_trigger_last_frame = true
                end
                
            else
                state = "idle"
                player_in_trigger = false
                player_in_trigger_last_frame = false
            end

        else--if the player is invisiable
            state = "idle"
            player_in_trigger = false
            player_in_trigger_last_frame = false
        end
    end

end

-- same for exiting a trigger
function on_trigger_exit(col)
    if (col.second_object.name == "Player") and state ~= "gameover" then
        state = "idle"
        color_target = color_regular
        player_in_trigger = false
        player_in_trigger_last_frame = false
    end
end


-- if the gameobject that this behavior is on has a ColliderComponent with collision monitor enabled, this function will be called
-- when something collides with the collider
function on_collision_enter(col)
    if (col.second_object.name == "Player") then
    
        if false == col.second_object.behavior:getBehavior("Player.lua").env.godmode then
            -- TODO remove this and add a proper LevelRestart script
            state = "gameover"
            chase_target = col.second_object
            player = chase_target
            player.behavior:getBehavior("Player.lua").env:die()
        end
        
    end
end

--[[
also available

on_trigger_enter - Trigger entered
on_trigger_stay  - Still in the trigger
on_trigger_exit  - Trigger exited 

on_collision_enter - Collision started
on_collision_stay  - Touching on this frame and previous frame
on_collision_exit  - Collsion ended

]]

function receive_message(message, sender)

    if message == "Sound" then
        state = "search"
        distract(sender.transform.position)
    end

    if message == "crush" then
        health = 0
    end

end


