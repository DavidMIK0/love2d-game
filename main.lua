local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function love.load()
    player = {
        width = 50,
        height = 100,
        x = love.graphics.getWidth() / 2 - 25,
        y = love.graphics.getHeight() / 2 - 50,
        hp = 100,
        speed = 200,
        clickCooldown = 0,
        attackRange = 120
    }

    enemy = {
        mapX = 100,
        mapY = 100,
        width = 40,
        height = 80,
        speed = 100,
        followDistance = 250,
        damageTimer = 0,
        hp = 100,
        dead = false,
        deathTimer = 0
    }

    mapX, mapY = 0, 0

    respawnButton = {
        x = love.graphics.getWidth() / 2 - 60,
        y = love.graphics.getHeight() / 2 + 30,
        w = 120,
        h = 40
    }

    font = love.graphics.newFont(20)
end

function love.update(dt)
    -- Player movement (moves the world, not the player)
    local moveX, moveY = 0, 0
    if love.keyboard.isDown("d") then moveX = moveX + 1 end
    if love.keyboard.isDown("a") then moveX = moveX - 1 end
    if love.keyboard.isDown("w") then moveY = moveY - 1 end
    if love.keyboard.isDown("s") then moveY = moveY + 1 end

    local length = math.sqrt(moveX * moveX + moveY * moveY)
    if length > 0 and player.hp > 0 then
        moveX, moveY = moveX / length, moveY / length
        mapX = mapX - moveX * dt * player.speed
        mapY = mapY - moveY * dt * player.speed
    end

    -- Enemy logic
    if not enemy.dead then
        local playerCenterX = player.x + player.width / 2
        local playerCenterY = player.y + player.height / 2
        local enemyScreenX = enemy.mapX + mapX
        local enemyScreenY = enemy.mapY + mapY
        local enemyCenterX = enemyScreenX + enemy.width / 2
        local enemyCenterY = enemyScreenY + enemy.height / 2
        local dx = playerCenterX - enemyCenterX
        local dy = playerCenterY - enemyCenterY
        local dist = math.sqrt(dx * dx + dy * dy)

        local touching = rectsOverlap(player.x, player.y, player.width, player.height, enemyScreenX, enemyScreenY, enemy.width, enemy.height)

        -- Only move enemy if not touching player
        if dist < enemy.followDistance and not touching then
            local ex, ey = dx / dist, dy / dist
            enemy.mapX = enemy.mapX + ex * enemy.speed * dt
            enemy.mapY = enemy.mapY + ey * enemy.speed * dt
        end

        -- Deal damage every second if touching
        if touching and player.hp > 0 then
            enemy.damageTimer = enemy.damageTimer - dt
            if enemy.damageTimer <= 0 then
                player.hp = math.max(0, player.hp - 10)
                enemy.damageTimer = 1
            end
        else
            enemy.damageTimer = 0
        end
    elseif enemy.deathTimer > 0 then
        enemy.deathTimer = enemy.deathTimer - dt
        if enemy.deathTimer <= 0 then
            enemy.deathTimer = 0
        end
    end

    -- Update player click cooldown
    if player.clickCooldown > 0 then
        player.clickCooldown = player.clickCooldown - dt
        if player.clickCooldown < 0 then player.clickCooldown = 0 end
    end
end

function love.draw()
    -- Draw map (background)
    love.graphics.setColor(0.2, 0.6, 0.2)
    love.graphics.rectangle("fill", mapX, mapY, 800, 600)

    -- Draw enemy (if not dead or in death animation)
    if not enemy.dead or (enemy.dead and enemy.deathTimer > 0) then
        if enemy.dead then
            love.graphics.setColor(1, 0, 0) -- red when dead
        else
            love.graphics.setColor(1, 0, 1)
        end
        love.graphics.rectangle("fill", enemy.mapX + mapX, enemy.mapY + mapY, enemy.width, enemy.height)
        -- Draw enemy HP above enemy
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(font)
        love.graphics.printf(
            "HP: " .. math.floor(enemy.hp),
            enemy.mapX + mapX,
            enemy.mapY + mapY - 25,
            enemy.width,
            "center"
        )
    end

    -- Draw player (always in center)
    love.graphics.setColor(0, 0, 1)
    love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)

    -- Draw player HP
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(font)
    love.graphics.print("Player HP: " .. math.floor(player.hp), 10, 10)

    -- Draw game over and respawn button if dead
    if player.hp <= 0 then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("Game Over", love.graphics.getWidth() / 2 - 50, love.graphics.getHeight() / 2 - 20)
       
        -- Draw respawn button
        love.graphics.setColor(0.2, 0.8, 0.2)
        love.graphics.rectangle("fill", respawnButton.x, respawnButton.y, respawnButton.w, respawnButton.h, 8, 8)
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf("Respawn", respawnButton.x, respawnButton.y + 10, respawnButton.w, "center")
    end
end

function love.mousepressed(x, y, button)
    if player.hp <= 0 and button == 1 then
        if x >= respawnButton.x and x <= respawnButton.x + respawnButton.w and
           y >= respawnButton.y and y <= respawnButton.y + respawnButton.h then
            player.hp = 100
            mapX, mapY = 0, 0
        end
    end

    if button == 1 and player.clickCooldown == 0 and not enemy.dead then
        local enemyScreenX = enemy.mapX + mapX
        local enemyScreenY = enemy.mapY + mapY
        if x >= enemyScreenX and x <= enemyScreenX + enemy.width and
           y >= enemyScreenY and y <= enemyScreenY + enemy.height then

            local playerCenterX = player.x + player.width / 2
            local playerCenterY = player.y + player.height / 2
            local enemyCenterX = enemyScreenX + enemy.width / 2
            local enemyCenterY = enemyScreenY + enemy.height / 2
            local dx = playerCenterX - enemyCenterX
            local dy = playerCenterY - enemyCenterY
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist <= player.attackRange then
                enemy.hp = math.max(0, enemy.hp - 20)
                player.clickCooldown = 1
                if enemy.hp <= 0 then
                    enemy.dead = true
                    enemy.deathTimer = 1
                end
            end
        end
    end
end