function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function getPlayerDamage()
    if player.equipped then
        if player.equipped.id == "sword" then
            return 20
        elseif player.equipped.id == "axe" then
            return 30
        end
    end
    return 10
end

function love.load()
    droppedItems = {}

    player = {
        width = 50,
        height = 100,
        x = love.graphics.getWidth() / 2 - 25,
        y = love.graphics.getHeight() / 2 - 50,
        hp = 100,
        lvl = 1,
        xp = 0,
        requiredXp = 100,
        speed = 200,
        clickCooldown = 0,
        attackRange = 120,
        equipped = nil
    }

    -- Player inventory
    player.inventory = {}
    player.inventoryCols = 9
    player.inventoryRows = 3
    player.inventorySlotSize = 40
    player.invW = player.inventoryCols * player.inventorySlotSize
    player.invH = player.inventoryRows * player.inventorySlotSize
    player.invX = love.graphics.getWidth() / 2 - player.invW / 2
    player.invY = love.graphics.getHeight() / 2 - player.invH / 2
    player.inventoryEnabled = false

    -- Fill inventory with empty slots
    for row = 1, player.inventoryRows do
        player.inventory[row] = {}
        for col = 1, player.inventoryCols do
            player.inventory[row][col] = { id = nil, count = 0 }
        end
    end

    -- Multiple enemies
    enemies = {}
    mapX, mapY = 0, 0

    for i = 1, 10 do
        local angle = math.random() * 2 * math.pi
        local distance = math.random(400, 600)
        local enemyWidth, enemyHeight = 40, 80
        local px = player.x + player.width / 2
        local py = player.y + player.height / 2
        local ex = -mapX + px + math.cos(angle) * distance - enemyWidth / 2
        local ey = -mapY + py + math.sin(angle) * distance - enemyHeight / 2

        -- Weapon drop logic: 10% axe, else 30% sword, else nothing
        local weaponDrop = false
        local weaponType = nil
        local roll = math.random()
        if roll < 0.10 then
            weaponDrop = true
            weaponType = "axe"
        elseif roll < 0.40 then
            weaponDrop = true
            weaponType = "sword"
        end

        table.insert(enemies, {
            mapX = ex,
            mapY = ey,
            width = enemyWidth,
            height = enemyHeight,
            speed = 100,
            followDistance = 250,
            damageTimer = 0,
            hp = 100,
            dead = false,
            deathTimer = 0,
            xpDrop = math.random(5, 15),
            weaponDrop = weaponDrop,
            weaponType = weaponType
        })
    end

    -- Spawn pebbles
    for i = 1, 15 do
        local angle = math.random() * 2 * math.pi
        local distance = math.random(300, 700)
        local px = player.x + player.width / 2
        local py = player.y + player.height / 2
        local rx = px + math.cos(angle) * distance
        local ry = py + math.sin(angle) * distance
        table.insert(droppedItems, {
            x = rx,
            y = ry,
            type = "pebble",
            canBePickedUp = true
        })
    end

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
    for _, enemy in ipairs(enemies) do
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

            if dist < enemy.followDistance and not touching then
                local ex, ey = dx / dist, dy / dist
                enemy.mapX = enemy.mapX + ex * enemy.speed * dt
                enemy.mapY = enemy.mapY + ey * enemy.speed * dt
            end

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

                if enemy.weaponDrop then
                    table.insert(droppedItems, {
                        x = enemy.mapX,
                        y = enemy.mapY,
                        type = enemy.weaponType,
                        canBePickedUp = true
                    })
                end
                player.xp = player.xp + enemy.xpDrop
            end
        end
    end

    -- Item pickup logic (only for weapons, by walking over)
    for i = #droppedItems, 1, -1 do
        local item = droppedItems[i]
        if (item.type == "sword" or item.type == "axe") and item.canBePickedUp ~= false then
            if rectsOverlap(
                player.x, player.y, player.width, player.height,
                item.x + mapX, item.y + mapY, 20, 20
            ) then
                for row = 1, player.inventoryRows do
                    for col = 1, player.inventoryCols do
                        local slot = player.inventory[row][col]
                        if not slot.id then
                            slot.id = item.type
                            slot.count = 1
                            table.remove(droppedItems, i)
                            goto weapon_picked_up
                        end
                    end
                end
            end
        end
        ::weapon_picked_up::
    end

    -- Update player click cooldown
    if player.clickCooldown > 0 then
        player.clickCooldown = player.clickCooldown - dt
        if player.clickCooldown < 0 then player.clickCooldown = 0 end
    end

    if player.xp >= player.requiredXp then
        player.lvl = player.lvl + 1
        player.xp = player.xp - player.requiredXp
        player.requiredXp = math.floor(player.requiredXp * 1.5)
        player.hp = math.min(player.hp + 20, 100)
    end
end

function love.draw()
    -- Draw map
    love.graphics.setColor(0.2, 0.6, 0.2)
    love.graphics.rectangle("fill", mapX, mapY, 800, 600)

    -- Draw dropped items
    for _, item in ipairs(droppedItems) do
        if item.type == "sword" then
            love.graphics.setColor(0.8, 0.8, 0.2)
            love.graphics.rectangle("fill", item.x + mapX, item.y + mapY, 20, 20)
        elseif item.type == "axe" then
            love.graphics.setColor(0.4, 0.7, 0.2)
            love.graphics.rectangle("fill", item.x + mapX, item.y + mapY, 20, 20)
        elseif item.type == "pebble" then
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.rectangle("fill", item.x + mapX, item.y + mapY, 14, 14)
        else
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("fill", item.x + mapX, item.y + mapY, 14, 14)
        end
        love.graphics.setColor(1, 1, 1)
    end

    -- Draw all enemies
    for _, enemy in ipairs(enemies) do
        if not enemy.dead or (enemy.dead and enemy.deathTimer > 0) then
            if enemy.dead then
                love.graphics.setColor(1, 0, 0)
            else
                love.graphics.setColor(1, 0, 1)
            end
            love.graphics.rectangle("fill", enemy.mapX + mapX, enemy.mapY + mapY, enemy.width, enemy.height)
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
    end

    -- Draw player (always in center)
    love.graphics.setColor(0, 0, 1)
    love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)

    -- Draw equipped weapon in player's hands
    if player.equipped then
        if player.equipped.id == "sword" then
            love.graphics.setColor(0.8, 0.8, 0.2)
            local swordX = player.x + player.width - 10
            local swordY = player.y + player.height / 2
            love.graphics.rectangle("fill", swordX, swordY, 8, 32)
            love.graphics.setColor(1, 1, 1)
        elseif player.equipped.id == "axe" then
            love.graphics.setColor(0.4, 0.7, 0.2)
            local axeX = player.x + player.width - 16
            local axeY = player.y + player.height / 2
            love.graphics.rectangle("fill", axeX, axeY, 16, 32)
            love.graphics.setColor(1, 1, 1)
        end
    end

    -- Draw player stats
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(font)
    love.graphics.print("HP: " .. math.floor(player.hp), 10, 10)
    love.graphics.print("LVL: " .. math.floor(player.lvl), 10, 40)
    love.graphics.print("XP: " .. math.floor(player.xp) .. " / " .. player.requiredXp, 10, 70)

    -- Draw player inventory
    if player.inventoryEnabled then
        for row = 1, player.inventoryRows do
            for col = 1, player.inventoryCols do
                local slot = player.inventory[row][col]
                local sx = player.invX + (col - 1) * player.inventorySlotSize
                local sy = player.invY + (row - 1) * player.inventorySlotSize

                -- Draw slot background
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.rectangle("fill", sx, sy, player.inventorySlotSize, player.inventorySlotSize)
                love.graphics.setColor(1, 1, 1)
                love.graphics.rectangle("line", sx, sy, player.inventorySlotSize, player.inventorySlotSize)

                -- Draw item
                if slot.id == "sword" then
                    love.graphics.setColor(0.8, 0.8, 0.2)
                    love.graphics.rectangle("fill", sx + 8, sy + 8, player.inventorySlotSize - 16, player.inventorySlotSize - 16)
                    love.graphics.setColor(1, 1, 1)
                elseif slot.id == "axe" then
                    love.graphics.setColor(0.4, 0.7, 0.2)
                    love.graphics.rectangle("fill", sx + 8, sy + 8, player.inventorySlotSize - 16, player.inventorySlotSize - 16)
                    love.graphics.setColor(1, 1, 1)
                elseif slot.id == "pebble" then
                    love.graphics.setColor(0.6, 0.6, 0.6)
                    love.graphics.rectangle("fill", sx + 14, sy + 14, player.inventorySlotSize - 28, player.inventorySlotSize - 28)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print(slot.count, sx + 4, sy + 4)
                end
            end
        end
    end

    -- Draw game over and respawn button if dead
    if player.hp <= 0 then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("Game Over", love.graphics.getWidth() / 2 - 50, love.graphics.getHeight() / 2 - 20)
        love.graphics.setColor(0.2, 0.8, 0.2)
        love.graphics.rectangle("fill", respawnButton.x, respawnButton.y, respawnButton.w, respawnButton.h, 8, 8)
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf("Respawn", respawnButton.x, respawnButton.y + 10, respawnButton.w, "center")
    end
end

function love.mousepressed(x, y, button)
    -- Respawn logic
    if player.hp <= 0 and button == 1 then
        if x >= respawnButton.x and x <= respawnButton.x + respawnButton.w and
           y >= respawnButton.y and y <= respawnButton.y + respawnButton.h then
            player.hp = 100
            mapX, mapY = 0, 0
        end
        return
    end

    -- Equip weapon with right click
    if player.inventoryEnabled and button == 2 then
        local mx, my = x, y
        for row = 1, player.inventoryRows do
            for col = 1, player.inventoryCols do
                local sx = player.invX + (col - 1) * player.inventorySlotSize
                local sy = player.invY + (row - 1) * player.inventorySlotSize
                if mx >= sx and mx <= sx + player.inventorySlotSize and my >= sy and my <= sy + player.inventorySlotSize then
                    local slot = player.inventory[row][col]
                    if slot.id == "sword" or slot.id == "axe" then
                        -- Swap equipped weapon with inventory slot
                        local prevEquipped = player.equipped
                        player.equipped = { id = slot.id }
                        if prevEquipped then
                            slot.id = prevEquipped.id
                            slot.count = 1
                        else
                            slot.id = nil
                            slot.count = 0
                        end
                    end
                end
            end
        end
        return
    end

    -- Pebble pickup (by clicking, always allowed)
    if button == 1 then
        local mx, my = x, y
        for i = #droppedItems, 1, -1 do
            local item = droppedItems[i]
            if item.type == "pebble" and item.canBePickedUp ~= false then
                local sx = item.x + mapX
                local sy = item.y + mapY
                if mx >= sx and mx <= sx + 14 and my >= sy and my <= sy + 14 then
                    -- Find first empty slot or stack
                    for row = 1, player.inventoryRows do
                        for col = 1, player.inventoryCols do
                            local slot = player.inventory[row][col]
                            if not slot.id then
                                slot.id = "pebble"
                                slot.count = 1
                                table.remove(droppedItems, i)
                                return
                            elseif slot.id == "pebble" then
                                slot.count = slot.count + 1
                                table.remove(droppedItems, i)
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    -- Attack enemy
    if button == 1 and player.clickCooldown == 0 then
        for _, enemy in ipairs(enemies) do
            if not enemy.dead then
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
                        enemy.hp = math.max(0, enemy.hp - getPlayerDamage())
                        player.clickCooldown = 1
                        if enemy.hp <= 0 then
                            enemy.dead = true
                            enemy.deathTimer = 1
                        end
                    end
                end
            end
        end
    end
end

function love.keypressed(key)
    if key == "e" then
        player.inventoryEnabled = not player.inventoryEnabled
    end
end