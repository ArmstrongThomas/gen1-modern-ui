-- RBYMMO -> Gen1 Modern UI adapter template.
-- This covers the public profile, rank, and character-pick payloads used by
-- the current RBYMMO compatibility bridge. Keep avatar art source-owned.
return function(mod)
  local ui = mod.find and mod.find("gen1_modern_ui") or nil
  if not (ui and ui.exports and ui.exports.registerAdapter) then
    return false, "Gen1 Modern UI is not installed"
  end

  local function normalizedId(value)
    return type(value) == "string"
      and value:lower():gsub("[^a-z0-9]", "") or ""
  end

  local function call(state, names, ...)
    for _, name in ipairs(names) do
      if type(state[name]) == "function" then
        return state[name](state, ...)
      end
    end
    return false
  end

  local function back(game, state)
    if call(state, { "back", "close", "exit" }) ~= false then return true end
    if game and game.stack and type(game.stack.pop) == "function" then
      game.stack:pop()
      return true
    end
    return false
  end

  local function playtime(value)
    local seconds = math.max(0, tonumber(value) or 0)
    return ("%d:%02d"):format(math.floor(seconds / 3600),
      math.floor(seconds / 60) % 60)
  end

  local function profileModel(game, state)
    local player = state.player or {}
    local card = player.profile
    local rows = {
      {
        label = player.name or "UNKNOWN",
        value = player.sprite or "TRAINER",
        image = player.image or player.icon or player.portrait or player.sprite,
      },
    }
    if type(card) == "table" then
      rows[#rows + 1] = { label = "ID NO", value = ("%05d"):format(tonumber(card.idNo) or 0) }
      rows[#rows + 1] = { label = "TIME", value = playtime(card.playtime) }
      rows[#rows + 1] = { label = "BADGES", value = tostring(card.badges or 0) }
      rows[#rows + 1] = { label = "RANK", value = tostring(player.points or 0) }
      rows[#rows + 1] = { label = "SEEN", value = tostring(card.seen or 0) }
      rows[#rows + 1] = { label = "OWNED", value = tostring(card.owned or 0) }
      if player.money ~= nil then
        rows[#rows + 1] = { label = "MONEY", value = ("Y%s"):format(tostring(player.money)) }
      end
    else
      rows[#rows + 1] = { label = "STATUS", value = "NO CARD SENT", enabled = false }
    end
    return {
      title = "TRAINER PROFILE",
      rows = rows,
      index = 1,
      footer = { "A / B back" },
      assets = state.assets,
    }
  end

  local function rankModel(game, state)
    local rows = {}
    for index, source in ipairs(state.rows or state.entries or {}) do
      rows[#rows + 1] = {
        label = source.name or source.player or "UNKNOWN",
        value = tostring(source.points or source.score or 0),
        image = source.image or source.icon or source.portrait or source.sprite,
        marker = index == (state.selected or 1),
      }
    end
    if #rows == 0 then
      rows[1] = { label = state.status or "NO RANKINGS", enabled = false }
    end
    return {
      title = "RANK",
      rows = rows,
      index = state.selected or 1,
      scroll = state.offset or 0,
      footer = { "UP/DOWN scroll", "B back" },
      assets = state.assets,
    }
  end

  local function characterModel(game, state)
    local rows = {}
    for _, source in ipairs(state.items or {}) do
      rows[#rows + 1] = {
        label = source.label or source.name or "CHARACTER",
        value = source.value or source.sprite,
        image = source.image or source.icon or source.portrait or source.sprite,
        enabled = source.enabled,
      }
    end
    return {
      title = "CHARACTER",
      rows = rows,
      index = state.index or 1,
      scroll = state.scroll or 0,
      footer = { "A choose", "B back" },
      assets = state.assets,
    }
  end

  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    screens = {
      Profile = {
        match = function(state)
          return normalizedId(state.screenId):find("rbymmoprofile", 1, true) ~= nil
            and type(state.player) == "table"
        end,
        model = profileModel,
        actions = { back = back },
        layer = "screen",
        canSuppressNative = true,
      },
      Rank = {
        match = function(state)
          local id = normalizedId(state.screenId)
          return id:find("rbymmorank", 1, true) ~= nil
            and (type(state.rows) == "table" or type(state.entries) == "table")
        end,
        model = rankModel,
        actions = {
          up = function(game, state) return call(state, { "move", "moveCursor" }, -1) end,
          down = function(game, state) return call(state, { "move", "moveCursor" }, 1) end,
          back = back,
        },
        layer = "screen",
        canSuppressNative = true,
      },
      CharacterPick = {
        match = function(state)
          return normalizedId(state.screenId):find("rbymmocharpick", 1, true) ~= nil
            and type(state.items) == "table" and type(state.index) == "number"
        end,
        model = characterModel,
        actions = {
          up = function(game, state) return call(state, { "move", "moveCursor" }, -1) end,
          down = function(game, state) return call(state, { "move", "moveCursor" }, 1) end,
          select = function(game, state) return call(state, { "select", "choose" }) end,
          back = back,
        },
        layer = "screen",
        canSuppressNative = true,
      },
    },
  }

  return ui.exports.registerAdapter({ owner = mod.id,
    contract = mod.exports.gen1ModernUi })
end
