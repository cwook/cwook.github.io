
runmode_play = true
runmode_pause = true 

go.prefab = "Player.prefab"

-- helper function
function lerp(a, b, t)
    return a * (1 - t) + b * t
end

-- adding a print function to the lua vector2 type
-- TODO: move this to a util script
vector2.print = function(vec)
  return ("" .. vec.x .. ", " .. vec.y)
end
vector3.print = function(vec)
  return ("" .. vec.x .. ", " .. vec.y .. ", " .. vec.z)
end

-- helper function, convert degrees to radians
function deg2rad(degrees)
    return (degrees * math.pi) / 180
end

-- helper function, convert radians to degrees
function rad2deg(radians)
    return (180 * radians) / math.pi
end

-- variables in this table will be editable in the inspector
-- only supports numbers for now
--  * lua has no concept of int, float, double, only number
--    these are converted to their correct types on setting them
script_values =
{
    acceleration = 90,
    deacceleration = 55,
    max_speed = 5,

    aud_player_footstep = "PlayerFootstep",
    aud_player_footstep_hault = "PlayerFootstepHault",
    aud_win = "Win",
    aud_death = "Death",
    aud_throw = "Throw",

    anim_walk_side = "PCSideRun",
    anim_walk_up = "PCFrontRun",
    anim_walk_down = "PCBackRun",
    anim_idle_side = "PCSideIdle",
    anim_idle_up = "PCFrontIdle",
    anim_idle_down = "PCBackIdle",
    anim_death = "PCSideCaught",

    prefab_chronosphere = "Chronosphere.prefab",
    prefab_throw_object = "ThrowObject.prefab",

    key_use = "e",

    throw_power = 10,

    has_chronosphere = true

}

-- GLOBALS

played_step = -1

stamina = 0              -- the current stamina of the player
i = vector2.new() -- used for tracking WASD input

state = "alive"

invisible = false
godmode = false

footstep_frames_side = {}
footstep_frames_front = {}
footstep_frames_back  = {}

function init()

    if string.len(script_values.prefab_chronosphere) == 0 then
        script_values.prefab_chronosphere = "Chronosphere.prefab"
    end
    if string.len(script_values.prefab_throw_object) == 0 then
        script_values.prefab_throw_object = "ThrowObject.prefab"
    end

    chronosphere = objectmanager:addPrefabAtPosition(script_values.prefab_chronosphere, transform.position)
    chronosphere_env = chronosphere.behavior:getBehavior("Chronosphere.lua").env
    
    throw_object_init = false
    
    throw_object = objectmanager:findGameObject("ThrowObject")

    if script_values.has_chronosphere then
        if throw_object == nil then
            throw_object = objectmanager:addPrefabAtPosition(script_values.prefab_throw_object, transform.position)
        end
        throw_object_env = throw_object.behavior:getBehavior("ThrowObject.lua").env
    else
        throw_object_init = true
        if throw_object == nil then
            print("Player can't find ThrowObject in the scene! Make sure it's named exactly the same.")
        else
            throw_object_env = throw_object.behavior:getBehavior("ThrowObject.lua").env
        end
    end

    state = "alive"

    --[[
    beacon = objectmanager:createGameObject("Beacon")
    local b_behavior_comp = beacon:addBehavior()
    local b_behavior = b_behavior_comp:addBehavior()
    b_behavior:loadScript("Beacon.lua")
    b_behavior.env:init()
    ]]
    --[[
    vloomba = objectmanager:createGameObject("Vloomba")
    local v_behavior_comp = vloomba:addBehavior()
    local v_behavior = v_behavior_comp:addBehavior()
    v_behavior:loadScript("Vloomba.lua")
    ]]

    utility:subscribe("crush")
    
    audio:setParameter( "Level 1 Music", "PlayerStatus", 0.0 )

	go.name = "Player"
    
    renderable:setColor( 1.0, 1.0, 1.0, 1.0 )
    
end

function time_to_play_footstep()

    if (i.x ~= 0) then

        if (animation:getFrame() == 3 or animation:getFrame() == 17) and played_step ~= animation:getFrame() then
            return true
        end

    elseif (i.y ~= 0) then

        if (i.y < 0) then

            if (animation:getFrame() == 2 or animation:getFrame() == 15) and played_step ~= animation:getFrame() then
                return true
            end

        else

            if (animation:getFrame() == 2 or animation:getFrame() == 15) and played_step ~= animation:getFrame() then
                return true
            end

        end
    end
    
    

    return false 
    
end


function update(dt)
    
    if throw_object_env ~= nil then
        if false == script_values.has_chronosphere then
            if throw_object_init and throw_object_env.initialized then
                throw_object_env:start_pickup(chronosphere, chronosphere_env)
                throw_object_init = false
            end
        end
    end

    if state == "dead" then
    
        if input:keyPressed("R") then
            local filename = currentscene:getFilename()
            currentscene:load( filename )
        end

        -- don't do the rest of the update
        return
    
    end
    
    i = vector2.new()
    if (input:keyHeld('D')) then
        i.x = i.x + 1
    end
    if (input:keyHeld('A')) then
        i.x = i.x - 1
    end
    if (input:keyHeld('W')) then
        i.y = i.y + 1
    end
    if (input:keyHeld('S')) then
        i.y = i.y - 1
    end
    
    -- footstep type via material map
    local mat = materialmap:get(transform.position)
    audio:setParameter(script_values.aud_player_footstep, "SurfaceType", mat.sound)
    audio:setParameter(script_values.aud_player_footstep_hault, "SurfaceType", mat.sound)

    -- normalized input vector length
    local i_length = i:length()
    if i_length == 0 then
        
        -- stopped walking
        if input:keyReleased('D') or input:keyReleased('A') or input:keyReleased('W') or input:keyReleased('S') then
            if input:keyReleased('D') or input:keyReleased('A') then
                animation:setAnimation(script_values.anim_idle_side)
            elseif input:keyReleased('W') then
                animation:setAnimation(script_values.anim_idle_down)
            elseif input:keyReleased('S') then
                animation:setAnimation(script_values.anim_idle_up)
            end
            audio:stopEvent(script_values.aud_player_footstep, false)
            audio:playEvent(script_values.aud_player_footstep_hault)
        end
    else

        if (i.x ~= 0) then
            animation:setAnimation(script_values.anim_walk_side)
            if (i.x > 0) then
                renderable:setFlipX(true)
            else
                renderable:setFlipX(false)
            end
        elseif (i.y ~= 0) then
            renderable:setFlipX(false)
            if (i.y < 0) then
                animation:setAnimation(script_values.anim_walk_up)
            else
                animation:setAnimation(script_values.anim_walk_down)
            end
        end

        if time_to_play_footstep() then
            played_step = animation:getFrame()
            audio:playAndForgetEvent(script_values.aud_player_footstep)
            if particle_emitter0 ~= nil then
                particle_emitter0:emitInstant()
            end
            if particle_emitter1 ~= nil then
                particle_emitter1:emitInstant()
            end
            if particle_emitter2 ~= nil then
                particle_emitter2:emitInstant()
            end
        end

    end

    if i_length > 1 then
        i.x = i.x / i_length
        i.y = i.y / i_length
    end
      
    -- add a force in the direction of input
    physicsbody:addForce( vector2.new( i.x * script_values.acceleration, i.y * script_values.acceleration ) )
    
    if throw_object_env ~= nil then
        local wp = utility:toWorld( vector2.new( input:mousePosition().x, input:mousePosition().y ) )
        
        if chronosphere_env.countdown <= 0 and script_values.has_chronosphere and input:mouseRightHeld() then
            
            throw_object_env:preview(vector2.new(transform.position.x, transform.position.y), wp)

            if input:mouseLeftClicked() then
                wp = vector3.new(wp.x, wp.y, 0)
                start_throw( wp )
            end

        end
        
    end
    
    if input:keyPressed("0") then
        if invisible then
            invisible = false
        else
            invisible = true
        end
    end
    
    if input:keyPressed("9") then
        if godmode then
            godmode = false
        else
            godmode = true
        end
    end
    
    if input:keyPressed("0") or input:keyPressed("9") then
        if invisible and godmode then
            renderable:setColor( 10.0, 3.0, 1.0, 0.5 )
        elseif invisible then
            renderable:setColor( 1.0, 1.0, 1.0, 0.3 )
        elseif godmode then
            renderable:setColor( 10., 3.0, 1.0, 1.0 )
        else
            renderable:setColor( 1.0, 1.0, 1.0, 1.0 )
        end
    end
end

function start_throw( position )

    if throw_object_env.state == "stopped" then
        throw_object_env:do_throw(transform.position, position, chronosphere, chronosphere_env)
    end

end

function late_update(dt)
    
    local v = physicsbody:getVelocity()
    local speed = v:length() -- calls DirectX::SimpleMath::GetLength() on the vector2 v
    local n = vector2.new( v.x / speed, v.y / speed )
  
    -- add deacceleration force
    if speed > 0 then
        if speed < 1 then
        physicsbody:addForce( vector2.new( -v.x * script_values.deacceleration, -v.y * script_values.deacceleration ) )
        else
        physicsbody:addForce( vector2.new( -n.x * script_values.deacceleration, -n.y * script_values.deacceleration ) )
        end
    end
    
    -- limit speed to max_speed
    if speed > script_values.max_speed then
        physicsbody:setVelocity( vector2.new( n.x * script_values.max_speed, n.y * script_values.max_speed ) )
    end
end

function receive_message(message, sender)

    if message == "crush" then
        print("player crushed")
        print("sender: " .. tostring(sender))
        print("sender.go: " .. tostring(sender.go))
        print("sender.go.name: " .. tostring(sender.go.name))

    end

end


function die()
    audio:setParameter( "Level 1 Music", "PlayerStatus", 1.0 )
    state = "dead"
    animation:setAnimation(script_values.anim_death)
    animation:setCommand("PlayOnce")

    uiManager:showScreen("LoseScreen", true)
end

function set_has_chronosphere(self, has_chrono)
    script_values.has_chronosphere = has_chrono
end

