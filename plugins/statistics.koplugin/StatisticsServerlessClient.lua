local logger = require("logger")
local socketutil = require("socketutil")

local PROGRESS_TIMEOUTS = { 2, 5 }
-- Use plugin-scoped middleware names to avoid mutating shared Spore middleware modules.
local STATS_GIN_MIDDLEWARE = "Spore.Middleware.StatisticsGinClient"
local STATS_AUTH_MIDDLEWARE = "Spore.Middleware.StatisticsAuth"

local StatisticsServerlessClient = {
    service_spec = nil,
    custom_url = nil,
}

function StatisticsServerlessClient:new(o)
    if o == nil then o = {} end
    setmetatable(o, self)
    self.__index = self
    if o.init then o:init() end
    return o
end

function StatisticsServerlessClient:init()
    local Spore = require("Spore")
    self.client = Spore.new_from_spec(self.service_spec, {
        base_url = self.custom_url,
    })
    if not package.preload[STATS_GIN_MIDDLEWARE] and not package.loaded[STATS_GIN_MIDDLEWARE] then
        package.preload[STATS_GIN_MIDDLEWARE] = function()
            return {
                call = function(_, req)
                    req.headers["accept"] = "application/vnd.koreader.v1+json"
                    req.headers["accept-encoding"] = "gzip"
                end,
            }
        end
    end
    if not package.preload[STATS_AUTH_MIDDLEWARE] and not package.loaded[STATS_AUTH_MIDDLEWARE] then
        package.preload[STATS_AUTH_MIDDLEWARE] = function()
            return {
                call = function(args, req)
                    req.headers["x-auth-user"] = args.username
                    req.headers["x-auth-key"] = args.userkey
                end,
            }
        end
    end
end

function StatisticsServerlessClient:sync_statistics(username, userkey, payload, callback)
    self.client:reset_middlewares()
    self.client:enable("Format.JSON")
    self.client:enable("StatisticsGinClient")
    self.client:enable("StatisticsAuth", {
        username = username,
        userkey = userkey,
    })
    socketutil:set_timeout(PROGRESS_TIMEOUTS[1], PROGRESS_TIMEOUTS[2])
    local ok, res = pcall(function()
        return self.client:sync_statistics(payload)
    end)
    socketutil:reset_timeout()
    if ok then
        callback(res.status == 200 or res.status == 202, res.body, res.status)
    else
        logger.dbg("StatisticsServerlessClient:sync_statistics failure:", res)
        callback(false, nil, nil)
    end
end

return StatisticsServerlessClient
