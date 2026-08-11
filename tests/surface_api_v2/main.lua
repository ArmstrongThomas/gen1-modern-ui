-- Isolated public-contract coverage for Gen1 Modern UI's v2 surface API.
--
-- Run from the repository root with:
--   & 'C:\\Program Files\\LOVE\\lovec.exe' tests/surface_api_v2
--
-- This harness loads the real mod entry point with a deliberately small host
-- mock. It does not duplicate production validation logic.

local assertions = 0
local skipped = 0

local function fail(message)
  error("surface API v2 test: " .. tostring(message), 0)
end

local function check(value, message)
  assertions = assertions + 1
  if not value then fail(message) end
end

local function contains(value, fragment)
  return type(value) == "string"
    and value:find(fragment, 1, true) ~= nil
end

local function skip(message)
  skipped = skipped + 1
  print("surface API v2 test: SKIP - " .. tostring(message))
end

function love.errorhandler(message)
  io.stderr:write(tostring(message), "\n", debug.traceback(), "\n")
  os.exit(1)
end

local function createHost()
  local activeOwners = {}
  local hooks = {}
  local events = {}
  local optionValues = {}
  local savedValues = {}

  local mod = {
    find = function(owner)
      return activeOwners[owner]
    end,
    assets = {
      image = function(_, path)
        fail("unexpected asset load during API test: " .. tostring(path))
      end,
    },
    hooks = {
      wrap = function(_, name, callback)
        hooks[name] = callback
      end,
    },
    events = {
      on = function(_, name, callback)
        events[name] = callback
      end,
    },
    options = {
      define = function(_, schema)
        for _, row in ipairs(schema or {}) do
          if optionValues[row.key] == nil then
            optionValues[row.key] = row.default
          end
        end
      end,
      get = function(_, key)
        return optionValues[key]
      end,
    },
    input = {
      tap = function()
        return true
      end,
    },
    ui = {},
    save = {
      get = function(_, key, fallback)
        local value = savedValues[key]
        if value == nil then return fallback end
        return value
      end,
      set = function(_, key, value)
        savedValues[key] = value
      end,
    },
  }

  local host = {
    mod = mod,
    hooks = hooks,
    events = events,
    options = optionValues,
  }

  function host:activate(owner)
    activeOwners[owner] = {
      id = owner,
      version = "test",
      exports = {},
    }
    return activeOwners[owner]
  end

  function host:deactivate(owner)
    activeOwners[owner] = nil
  end

  return host
end

local function loadProductionMod(host)
  local entryPath = os.getenv("GEN1_UI_MAIN")
    or "mods/gen1_modern_ui/main.lua"
  local chunk, loadError = loadfile(entryPath)
  check(type(chunk) == "function", loadError or "production entry loads")
  local installer = chunk()
  check(type(installer) == "function", "production entry returns an installer")
  installer(host.mod)
  check(type(host.mod.exports) == "table",
    "production installer publishes mod.exports")
  return host.mod.exports
end

local function makeSurfaceContract(mutator)
  local surface = {
    match = function(state)
      return state and state.screenId == "SurfaceApiV2Fixture"
    end,
    model = function()
      return {
        title = "SURFACE API V2",
        rows = { { label = "FIXTURE" } },
      }
    end,
    render = function()
      return true
    end,
    layout = {
      virtualWidth = 320,
      virtualHeight = 180,
      preset = "VIEWPORT",
      fit = "contain",
      scaleMode = "integer-fit",
    },
    native = {
      policy = "replace",
      scope = "uiCanvas",
    },
  }
  if mutator then mutator(surface) end
  return {
    apiVersion = 2,
    surfaces = { Fixture = surface },
  }
end

local function makeV1ScreenContract(extra)
  local screen = {
    match = function(state)
      return state and state.screenId == "LegacyDataFixture"
    end,
    model = function()
      return {
        title = "LEGACY DATA SCREEN",
        rows = { { label = "ROW" } },
        index = 1,
        scroll = 0,
      }
    end,
    canSuppressNative = true,
  }
  for key, value in pairs(extra or {}) do screen[key] = value end
  return {
    apiVersion = 1,
    screens = { LegacyDataFixture = screen },
  }
end

local function expectRejected(api, host, owner, contract, reasonFragment,
    label)
  host:activate(owner)
  local registered, reason = api.registerAdapter({
    owner = owner,
    contract = contract,
  })
  check(registered == false, label .. " is rejected")
  check(contains(reason, reasonFragment),
    label .. " reports the expected reason (got " .. tostring(reason) .. ")")
end

local function verifyVersionAndCapabilities(api)
  check(api.version == 1, "api.version remains 1")
  check(api.compatibilityApiVersion == 1,
    "compatibilityApiVersion remains 1")
  check(api.surfaceApiVersion == 2, "surfaceApiVersion is 2")
  check(type(api.supportedApiVersions) == "table"
      and api.supportedApiVersions[1] == 1
      and api.supportedApiVersions[2] == 2,
    "supportedApiVersions publishes versions 1 and 2")
  check(type(api.supports) == "function", "supports is publicly callable")

  check(api.supports("data_screens", 1),
    "v1 data screens remain advertised")
  check(api.supports("additive_extensions", 1),
    "v1 additive extensions remain advertised")
  check(api.supports("data_screens", 2),
    "v2 remains compatible with v1 data screens")

  for _, capability in ipairs({
      "custom_fields", "footer_lists", "modal_overlay",
      "custom_surface", "isolated_shader",
    }) do
    check(api.supports(capability, 2),
      capability .. " is advertised for v2")
    check(not api.supports(capability, 1),
      capability .. " is not falsely advertised for v1")
    check(api.supports(capability),
      capability .. " is discoverable without a version filter")
  end

  check(not api.supports("not_a_real_capability", 2),
    "unknown capabilities are rejected")
  check(not api.supports("custom_surface", 99),
    "unsupported API versions are rejected")
end

local function verifyV1Boundary(api, host)
  for _, field in ipairs({ "draw", "render", "drawCallback" }) do
    expectRejected(api, host, "v1_custom_" .. field,
      makeV1ScreenContract({ [field] = function() end }),
      "custom draw callbacks are not supported",
      "v1 screen " .. field .. " callback")
  end

  expectRejected(api, host, "v1_surface_descriptor",
    {
      apiVersion = 1,
      surfaces = makeSurfaceContract().surfaces,
    },
    "contract.surfaces requires apiVersion 2",
    "v1 surface descriptor")
  expectRejected(api, host, "v1_custom_named_action",
    makeV1ScreenContract({ actions = { search = function() return true end } }),
    "unsupported semantic action",
    "v1 custom named screen action")
end

local function verifyInvalidV2Contracts(api, host)
  local dimensionCases = {
    {
      owner = "surface_width_zero",
      label = "zero virtual width",
      mutate = function(surface) surface.layout.virtualWidth = 0 end,
      reason = "surface layout requires a virtual canvas",
    },
    {
      owner = "surface_height_too_large",
      label = "virtual height above 2048",
      mutate = function(surface) surface.layout.virtualHeight = 2049 end,
      reason = "surface layout requires a virtual canvas",
    },
    {
      owner = "surface_area_too_large",
      label = "virtual canvas above four million pixels",
      mutate = function(surface)
        surface.layout.virtualWidth = 2001
        surface.layout.virtualHeight = 2000
      end,
      reason = "surface layout requires a virtual canvas",
    },
    {
      owner = "surface_bad_portrait_size",
      label = "unsafe portrait virtual canvas",
      mutate = function(surface)
        surface.layout.portrait = { virtualWidth = 320, virtualHeight = 4096 }
      end,
      reason = "surface orientation canvas exceeds the safe limit",
    },
  }
  for _, case in ipairs(dimensionCases) do
    expectRejected(api, host, case.owner,
      makeSurfaceContract(case.mutate), case.reason, case.label)
  end

  expectRejected(api, host, "surface_missing_native_policy",
    makeSurfaceContract(function(surface)
      surface.native = {}
    end),
    "surface native.policy must explicitly be replace or preserve",
    "missing native policy")

  expectRejected(api, host, "surface_invalid_native_policy",
    makeSurfaceContract(function(surface)
      surface.native.policy = "sometimes"
    end),
    "surface native.policy must explicitly be replace or preserve",
    "invalid native policy")

  expectRejected(api, host, "surface_invalid_native_scope",
    makeSurfaceContract(function(surface)
      surface.native.scope = "wholeWindow"
    end),
    "surface native.scope must be uiCanvas",
    "invalid native scope")

  expectRejected(api, host, "surface_invalid_fit",
    makeSurfaceContract(function(surface)
      surface.layout.fit = "cover"
    end),
    "surface layout.fit currently supports only contain",
    "unsupported surface fit")

  expectRejected(api, host, "surface_invalid_scale_mode",
    makeSurfaceContract(function(surface)
      surface.layout.scaleMode = "stretch"
    end),
    "surface scaleMode must be integer-fit or smooth-fit",
    "unsupported surface scale mode")
end

local function verifyStructuredV2Screens(api, host)
  local owner = "surface_api_v2_structured_screen"
  host:activate(owner)
  local selectedPayload
  local contract = {
    apiVersion = 2,
    screens = {
      StructuredFixture = {
        match = function(state)
          return state and state.screenId == "StructuredV2Fixture"
        end,
        model = function()
          return {
            title = "STRUCTURED",
            rows = { { label = "ODDISH" } },
            details = {
              species = "Oddish",
              custom_fields = { columns = 4, data = {
                { label = "HP", value = 45 },
                { label = "TOTAL", value = 255, style = "accent" },
              } },
              footer_lists = { { title = "ENCOUNTER", items = {
                { label = "GRASS", value = "24%" },
              } } },
            },
            layout_options = {
              overflow = "shrink_to_fit",
              max_content_height = "100%",
            },
          }
        end,
        canSuppressNative = true,
        actions = {
          select = function()
            return {
              type = "modal_overlay", dim_background = true,
              options = {
                { label = "SEARCH", action = "search",
                  payload = { species = "ODDISH" } },
              },
            }
          end,
          search = function(_, _, payload)
            selectedPayload = payload
            return true
          end,
        },
      },
    },
  }
  local registered, reason = api.registerAdapter({
    owner = owner, contract = contract,
  })
  check(registered == true,
    "v2 structured data screen registers: " .. tostring(reason))
  local compatibility = host.mod._gen1ModernCompatibility
  local state = { screenId = "StructuredV2Fixture", draw = function() end }
  local context = compatibility:adapterFor(nil, state)
  local model = compatibility:modelFor(nil, state, context)
  check(model and model.details and model.details.custom_fields
      and model.layoutOptions
      and model.layoutOptions.overflow == "shrink_to_fit",
    "v2 structured details and layout_options survive normalization")
  check(compatibility:action(nil, state, "select") == true
      and compatibility.declarativeModals[state] ~= nil,
    "v2 screen action opens a data-only modal_overlay")
  check(compatibility:action(nil, state, "select") == true
      and selectedPayload and selectedPayload.species == "ODDISH"
      and compatibility.declarativeModals[state] == nil,
    "modal selection routes to a named v2 screen action")
  check(api.unregisterAdapter(owner) == true,
    "v2 structured screen unregisters")
end

local function verifyRegistrationAndUnregister(api, host)
  local owner = "surface_v2_valid"
  host:activate(owner)
  local surfaceContract = makeSurfaceContract()
  surfaceContract.surfaces.Fixture.gallery = {
    name = "SURFACE FIXTURE", screenId = "SurfaceApiV2Fixture",
    category = "Integration",
    models = { normal = { title = "GALLERY FIXTURE" } },
  }
  local registered, reason = api.registerAdapter({
    owner = owner,
    version = "2.0-test",
    contract = surfaceContract,
  })
  check(registered == true,
    "valid apiVersion=2 surface registers: " .. tostring(reason))

  local compatibility = host.mod._gen1ModernCompatibility
  check(type(compatibility) == "table"
      and compatibility.adapters[owner]
      and compatibility.adapters[owner].contract.apiVersion == 2,
    "valid v2 registration reaches the compatibility registry")

  local state = {
    screenId = "SurfaceApiV2Fixture",
    draw = function() end,
  }
  local context = compatibility:surfaceFor(nil, state)
  check(context and context.owner == owner and context.id == "Fixture",
    "registered v2 surface matches its source state")
  local model = compatibility:surfaceModelFor(nil, state, context)
  check(model and model.title == "SURFACE API V2",
    "registered v2 surface produces a data-only model snapshot")
  local galleryId = "surface:" .. owner .. ":Fixture"
  local galleryFound = false
  for _, spec in ipairs(api.uiGalleryCatalog()) do
    if spec.id == galleryId and spec.kind == "custom_surface" then
      galleryFound = true
      break
    end
  end
  check(galleryFound,
    "surface Gallery fixtures publish a stable custom_surface specimen")

  check(api.unregisterAdapter(owner) == true,
    "public unregisterAdapter succeeds for a v2 owner")
  check(compatibility.adapters[owner] == nil,
    "unregister removes the v2 descriptor from the registry")
  for _, spec in ipairs(api.uiGalleryCatalog()) do
    check(spec.id ~= galleryId,
      "unregister removes the surface Gallery specimen")
  end
  check(compatibility:surfaceFor(nil, state) == nil,
    "an unregistered v2 surface no longer matches")

  local legacyOwner = "surface_api_v1_data"
  host:activate(legacyOwner)
  registered, reason = api.registerAdapter({
    owner = legacyOwner,
    contract = makeV1ScreenContract(),
  })
  check(registered == true,
    "v1 data screen still registers: " .. tostring(reason))

  local legacyState = {
    screenId = "LegacyDataFixture",
    draw = function() end,
  }
  local legacyContext = compatibility:adapterFor(nil, legacyState)
  check(legacyContext and legacyContext.owner == legacyOwner,
    "registered v1 data screen still matches")
  local legacyModel = compatibility:modelFor(nil, legacyState, legacyContext)
  check(legacyModel and legacyModel.rows
      and legacyModel.rows[1].label == "ROW",
    "registered v1 screen still normalizes its data model")
  check(api.unregisterAdapter(legacyOwner) == true,
    "public unregisterAdapter succeeds for a v1 owner")
end

local function verifyHighResolutionSurfaceLayout(host)
  local runtime = host.mod._gen1ModernSurfaceRuntime
  check(type(runtime) == "table" and type(runtime.layoutFor) == "function",
    "production custom-surface layout runtime is available")
  local layout = runtime:layoutFor({ surface = { layout = {
    virtualWidth = 960,
    virtualHeight = 640,
    preset = "XL",
    scaleMode = "smooth-fit",
  } } }, {
    width = 5120,
    height = 2784,
    safe = { x = 0, y = 0, width = 5120, height = 2784 },
  }, { scale = { ui = 4 } })
  check(layout.output.width == 3840 and layout.output.height == 2560,
    "preset-backed v2 surfaces honor the public 400% UI ceiling")
  check(layout.output.x >= 0 and layout.output.y >= 0
      and layout.output.x + layout.output.width <= 5120
      and layout.output.y + layout.output.height <= 2784,
    "400% v2 surface output remains inside the 5K safe viewport")
end

local function canvasAlpha(canvas)
  local image = canvas:newImageData()
  local _, _, _, alpha = image:getPixel(0, 0)
  return alpha
end

local function verifyRenderFailureFallsBack(api, host)
  -- Registration/discovery landed before the transactional surface renderer.
  -- Do not treat descriptor validation as render-safety coverage. Once the
  -- real runtime seam exists, these checks automatically become active.
  if type(host.mod._gen1ModernSurfaceRuntime) ~= "table" then
    skip("surface render transaction is not implemented in production yet; "
      .. "false/throw native-fallback coverage is intentionally not claimed")
    return
  end
  if not (love.graphics and type(love.graphics.newCanvas) == "function"
      and type(host.hooks["render.zones"]) == "function"
      and type(host.hooks["render.compose"]) == "function") then
    skip("surface render transaction exists, but this LÖVE host cannot run "
      .. "the compose fallback probe")
    return
  end

  local function runCase(owner, renderCallback, label, expectCleared,
      nativePolicy)
    host:activate(owner)
    local contract = makeSurfaceContract(function(surface)
      surface.render = renderCallback
      if nativePolicy then surface.native.policy = nativePolicy end
    end)
    local registered, reason = api.registerAdapter({
      owner = owner,
      contract = contract,
    })
    check(registered == true,
      label .. " fixture registers: " .. tostring(reason))

    local state = {
      screenId = "SurfaceApiV2Fixture",
      draw = function() end,
      isOpaque = true,
    }
    local stack = { states = { state } }
    function stack:top() return self.states[#self.states] end
    function stack:visibleBase() return 1 end
    local game = { stack = stack }

    host.hooks["render.zones"](
      function(_, zones) return zones end, game, {})

    local canvas = love.graphics.newCanvas(32, 32)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.25, 0.5, 0.75, 1)
    love.graphics.pop()

    host.hooks["render.compose"](function() return false end, {}, {
      uiCanvas = canvas,
      uiw = 32,
      uih = 32,
      ww = 320,
      wh = 180,
      pw = 320,
      ph = 180,
      dpiX = 1,
      dpiY = 1,
      scale = 1,
      ox = 0,
      oy = 0,
      vpw = 320,
      vph = 180,
    })
    if expectCleared then
      check(canvasAlpha(canvas) < 0.01,
        label .. " clears native uiCanvas only after commit")
    else
      check(canvasAlpha(canvas) > 0.99,
        label .. " leaves native uiCanvas intact")
    end
    check(api.unregisterAdapter(owner) == true,
      label .. " fixture unregisters")
  end

  local falseCalls = 0
  runCase("surface_render_false", function()
    falseCalls = falseCalls + 1
    return false
  end, "surface render returning false")
  check(falseCalls == 1,
    "false-returning surface renderer is actually exercised")

  local throwCalls = 0
  runCase("surface_render_throw", function()
    throwCalls = throwCalls + 1
    error("intentional surface render failure")
  end, "surface render throwing")
  check(throwCalls == 1,
    "throwing surface renderer is actually exercised")

  local successCalls = 0
  runCase("surface_render_success", function(model, ctx)
    successCalls = successCalls + 1
    love.graphics.clear(1, 1, 1, 1)
    return model and ctx and true
  end, "successful replace surface", true)
  check(successCalls == 1,
    "successful replace surface renderer is actually exercised")

  local preserveCalls = 0
  runCase("surface_render_preserve", function()
    preserveCalls = preserveCalls + 1
    return true
  end, "successful preserve surface", false, "preserve")
  check(preserveCalls == 1,
    "successful preserve surface renderer is actually exercised")
end

function love.load()
  io.stdout:setvbuf("no")
  local host = createHost()
  local api = loadProductionMod(host)

  verifyVersionAndCapabilities(api)
  verifyV1Boundary(api, host)
  verifyInvalidV2Contracts(api, host)
  verifyStructuredV2Screens(api, host)
  verifyRegistrationAndUnregister(api, host)
  verifyHighResolutionSurfaceLayout(host)
  verifyRenderFailureFallsBack(api, host)

  print(("surface API v2 test: PASS (%d assertions, %d skipped)")
    :format(assertions, skipped))
  love.event.quit(0)
end
