local PLUGIN_NAME = "rbl"

local helpers = require "spec.helpers"

describe("rbl", function()
  local client

  setup(function()
    local api1 = assert(helpers.dao.apis:insert { 
        name         = "api-1", 
        hosts        = { "test1.com" }, 
        upstream_url = "http://httpbin.org",
    })

    assert(helpers.dao.plugins:insert {
      api_id = api1.id,
      name   = PLUGIN_NAME,
      config = {
        rbl_srvs     = { "dnsbl.anticaptcha.net" },
        nameservers  = { "8.8.8.8" },
        cache_ttl    = 60,
        txt_followup = true,
      }
    })

    assert(helpers.start_kong {
      custom_plugins = PLUGIN_NAME,
      trusted_ips    = "127.0.0.1", -- use X-Real-IP as the source
    })
  end)

  teardown(function()
    helpers.stop_kong()
  end)

  before_each(function()
    client = helpers.proxy_client()
  end)

  after_each(function()
    if client then client:close() end
  end)

  describe("blacklisted client", function()
    it("is denied with a 403", function()
      local res = assert(client:send {
        method = "GET",
        path = "/get",
        headers = {
          ["Host"]      = "test1.com",
          ["X-Real-IP"] = "127.0.0.1",
        }
      })

      assert.res_status(403, res)
    end)
  end)

  describe("non-blacklisted client", function()
    it("is proxies upstream", function()
      local res = assert(client:send {
        method = "GET",
        path = "/get",
        headers = {
          ["Host"]      = "test1.com",
          ["X-Real-IP"] = "127.0.0.5",
        }
      })

      assert.res_status(200, res)
    end)
  end)
end)
