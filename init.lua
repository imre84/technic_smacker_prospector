local S = technic.getter
local mat = technic.materials


local function get_field(meta)
    return ( meta:get("look_radius") or 1 ) * 7
end


local function remove_waypoints(user, w)
    for i,p in ipairs(w) do
        user:hud_remove(p)
    end
end


technic.register_power_tool("technic_smacker_prospector:prospector_mk2", {
    description = S("Prospector Mk2"),
    inventory_image = "technic_prospector_mk2.png",
    max_charge = 650000,
    on_use = function(toolstack, user, pointed_thing)
        if not user or not user:is_player() or user.is_fake_player then return end
        if pointed_thing.type ~= "node" then return end
        local meta = toolstack:get_meta()
        local target = meta:get("target")
        if not target then
            minetest.chat_send_player(user:get_player_name(), S("Right-click to set target block type"))
            return toolstack
        end
        local look_radius = get_field(meta)
        local charge_to_take = math.pow(look_radius, 3)
        if not technic.use_RE_charge(toolstack, charge_to_take) then
            return toolstack
        end
        local start_pos = pointed_thing.under

        local min_pos = {x = start_pos.x - look_radius, y = start_pos.y - look_radius, z = start_pos.z - look_radius }

        local max_pos = {x = start_pos.x + look_radius, y = start_pos.y + look_radius, z = start_pos.z + look_radius }

        local results = minetest.find_nodes_in_area(min_pos, max_pos, target)

        local waypoints = {}
        local found = false

        if #results > math.pow(look_radius, 3) * 0.25 then
            minetest.chat_send_player(user:get_player_name(), S("@1 is literally everywhere within the scanned region",
                                                                minetest.registered_nodes[target].description))
        else
            for _,p in ipairs(results) do
                if math.random() >= 0.02 then
                    found = true
                    local idx = user:hud_add({
                        hud_elem_type = "waypoint",
                        name = "",
                        text = "",
                        number = 0xFF0000,
                        world_pos = p
                    })
                    table.insert(waypoints, idx)
                end
            end

            if found then
                minetest.after(7, remove_waypoints, user, waypoints)
            end

            minetest.chat_send_player(user:get_player_name(), S("@1 is " .. (found and "present" or "absent") ..
                                                                " within @2 meters radius",
                                                                minetest.registered_nodes[target].description,
                                                                look_radius))
        end

        minetest.sound_play("technic_prospector_" .. (found and "hit" or "miss"),
                            { pos = vector.add(user:getpos(), { x = 0, y = 1, z = 0 }),
                              gain = 1.0,
                              max_hear_distance = 10})

        return toolstack
    end,
    on_place = function(toolstack, user, pointed_thing)
        if not user or not user:is_player() or user.is_fake_player then return end
        local meta = toolstack:get_meta()
        local target = meta:get("target")
        local look_radius = get_field(meta)
        local pointed
        if pointed_thing.type == "node" then
            local pname = minetest.get_node(pointed_thing.under).name
            local pdef = minetest.registered_nodes[pname]
            if pdef and (pdef.groups.not_in_creative_inventory or 0) == 0 and pname ~= target then
                pointed = pname
            end
        end

        minetest.show_formspec(user:get_player_name(), "technic_smacker_prospector:prospector_control_mk2",
            "size[7,8.5]"..
            "item_image[0,0;1,1;"..toolstack:get_name().."]"..
            "label[1,0;"..minetest.formspec_escape(toolstack:get_description()).."]"..
            (target and
                "label[0,1.5;Current target:]"..
                "label[0,2;"..minetest.formspec_escape(minetest.registered_nodes[target].description).."]"..
                "item_image[0,2.5;1,1;"..target.."]" or
                "label[0,1.5;"..S("No target set").."]")..
            (pointed and
                "label[3.5,1.5;"..S("May set new target:").."]"..
                "label[3.5,2;"..minetest.formspec_escape(minetest.registered_nodes[pointed].description).."]"..
                "item_image[3.5,2.5;1,1;"..pointed.."]"..
                "button_exit[3.5,3.65;2,0.5;target_"..pointed..";"..S("Set target").."]" or
                "label[3.5,1.5;"..S("No new target available").."]")..
            "label[0,4.5;Scan radius:]"..
            "label[0,5;".. look_radius .."]"..
            "label[3.5,4.5;Set scan radius:]"..
            "button_exit[3.5,5.15;1,0.5;look_radius_1;7]"..
            "button_exit[4.5,5.15;1,0.5;look_radius_2;14]"..
            "button_exit[5.5,5.15;1,0.5;look_radius_3;21]"..
            "label[0,7.5;"..S("Accuracy:").."]"..
            "label[0,8;98%]")
        return
    end,
})

minetest.register_on_player_receive_fields(function(user, formname, fields)
    if formname ~= "technic_smacker_prospector:prospector_control_mk2" then return false end
    if not user or not user:is_player() or user.is_fake_player then return end
    local toolstack = user:get_wielded_item()

    if formname == "technic_smacker_prospector:prospector_control_mk2" and toolstack:get_name() == "technic_smacker_prospector:prospector_mk2" then
        local meta = toolstack:get_meta()
        for field, value in pairs(fields) do
            if field:sub(1, 7) == "target_" then
                meta:set_string("target", field:sub(8))
            elseif field:sub(1, 12) == "look_radius_" then
                meta:set_int("look_radius", field:sub(13))
            end
        end
        user:set_wielded_item(toolstack)
        return true
    end

    return true
end)

if not minetest.registered_items["pipeworks:teleport_tube_1"] then
    -- in case the teleporting tube is disabled in pipeworks:
    minetest.register_craftitem('technic_smacker_prospector:teleport_tube_1', {
        description = "Teleporting Pneumatic Tube Segment (disabled)",
        inventory_image = "pipeworks_teleport_tube_inv.png",
    })
    minetest.register_alias("pipeworks:teleport_tube_1", "technic_smacker_prospector:teleport_tube_1")
    minetest.register_craft({
        output = 'technic_smacker_prospector:teleport_tube_1',
        recipe = {
            {mat.mese_crystal, 'technic:copper_coil', mat.mese_crystal},
            {'pipeworks:tube_1', 'technic:control_logic_unit', 'pipeworks:tube_1'},
            {mat.mese_crystal, 'technic:copper_coil', mat.mese_crystal},
        }
    })
end

minetest.register_craftitem( "technic_smacker_prospector:control_logic_unit_adv", {
    description = S("Advanced Control Logic Unit"),
    inventory_image = "technic_control_logic_unit_adv.png",
})

minetest.register_craft({
    output = 'technic_smacker_prospector:control_logic_unit_adv',
    recipe = {
        {'','technic:control_logic_unit',''},
        {'','default:tin_ingot',''},
        {'','technic:control_logic_unit',''}
    }
})

minetest.register_craft({
    output = "technic_smacker_prospector:prospector_mk2",
    recipe = {
        {"moreores:pick_mithril", "moreores:mithril_block", "pipeworks:teleport_tube_1"},
        {"basic_materials:brass_ingot", "technic_smacker_prospector:control_logic_unit_adv", "basic_materials:brass_ingot"},
        {"", "technic:blue_energy_crystal", ""},
    }
})
