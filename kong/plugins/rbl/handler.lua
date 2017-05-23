local BasePlugin = require "kong.plugins.base_plugin"
local responses  = require "kong.tools.responses"
local semaphore  = require "ngx.semaphore"
local dns        = require "resty.dns.resolver"
local cache      = require "kong.tools.database_cache"


local ngx_log      = ngx.log
local table_concat = table.concat
local thread_spawn = ngx.thread.spawn
local thread_wait  = ngx.thread.wait
local max          = math.max


local DEBUG = ngx.DEBUG
local ERR   = ngx.ERR


local RBLHandler = BasePlugin:extend()

function RBLHandler:new()
  RBLHandler.super.new(self, "rbl")
end

local function dbg_log(...)
  ngx_log(DEBUG, ...)
end

local function err_log(...)
  ngx_log(ERR, ...)
end

local function reverse_octets(ip)
  if type(ip) ~= "string" then
    return false
  end

  local o1, o2, o3, o4 = ip:match("(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)")

  return table_concat({ o4, o3, o2, o1 }, ".")
end

local function parse_answers(answers)
  if answers.errcode == 3 then
    -- no answer
    return

  elseif answers.errcode then
    -- if the response code was 0, this field is nil,
    -- so we know we're in an error condition
    err_log("[rbl] error returned querying ", query_str, ": ", answers.errstr)
    return

  else
    local answer = answers[1]
    return answer.type == dns.TYPE_TXT and answer.txt or
      answer.name or answer.cname,
      answer.ttl
  end
end

local function do_query(query_str, conf, sem)
  -- resty.dns.resolver object
  local resolver

  do
    local err
    resolver, err = dns:new({
      nameservers = conf.nameservers,
    })
    if err then
      err_log("[rbl] error building resolver object: ", err)
      return
    end

    local ok
    ok, err = sem:wait(conf.lock_timeout)
    if err then
      err_log("[rbl] failed to acquire query resource: ", query_str)
      return
    end
  end

  dbg_log("[rbl] sem c: ", sem:count())
  dbg_log("[rbl] starting query")

  -- return objects
  local res, ttl

  do
    local answers, err = resolver:query(query_str)

    dbg_log("[rbl] query done")

    if not answers then
      err_log("[rbl] failed resolving ", query_str, ": ", err)

      sem:post()
      dbg_log("[rbl] semaphore release")
      dbg_log("[rbl] sem c: ", sem:count())

      return
    end

    res, ttl = parse_answers(answers)
  end

  local txt
  if res and conf.txt_followup then
    local txt_answers, err = resolver:query(query_str,
      { qtype = resolver.TYPE_TXT })

    if not txt_answers then
      err_log("[rbl] failed resolving TXT ", query_str, ": ", err)

    else
      txt = parse_answers(txt_answers)
      ngx.header["X-Kong-RBL-TXT"] = txt
    end
  end

  sem:post()
  dbg_log("[rbl] semaphore release")
  dbg_log("[rbl] sem c: ", sem:count())

  return res, ttl, txt
end

function RBLHandler:access(conf)
  RBLHandler.super.access(self)

  local octets, cache_key

  do
    local ip = ngx.var.remote_addr
    cache_key = "rbl-" .. ip

    local res = cache.get(cache_key)
    if res then
      if conf.txt_followup then
        ngx.header["X-Kong-RBL-TXT"] = res.txt
      end

      responses.send_HTTP_FORBIDDEN()

    elseif res == false then
      -- cached false, let them through
      return
    end

    octets = reverse_octets(ip)
    if not octets then
      err_log("[rbl] failed building query string")
      return
    end
  end

  -- setup a new semaphore with as many resources as the plugin allows
  local sem = semaphore.new(conf.concurrent_queries)

  -- co obj and results holders
  local threads = {}

  local n = #conf.rbl_srvs

  -- try to spawn our threads as quickly as possible
  -- we will end up back here to start a new thread as a result
  -- of either the semaphore wait, or the socket send
  for i = 1, n do
    dbg_log("[rbl] sem c: ", sem:count())
    dbg_log("[rbl] executing thread #", i)

    threads[i] = thread_spawn(
      do_query,
      octets .. "." .. conf.rbl_srvs[i],
      conf,
      sem
    )
  end

  -- search each thread; if we found a result, the call to send_HTTP_FORBIDDEN
  -- will kill the remaining threads via ngx.exit()
  for i = 1, n do
    local ok, res, ttl, txt = thread_wait(threads[i])

    if res then
      dbg_log("[rbl] found in thread #", i, ": ", res)
      dbg_log("[rbl] ttl ", ttl)

      cache.set(cache_key, { res = true, txt = txt }, max(ttl, conf.cache_ttl))

      responses.send_HTTP_FORBIDDEN()
    end
  end

  -- cache the negative result
  cache.set(cache_key, false, conf.cache_ttl)
end

RBLHandler.PRIORITY = 100

return RBLHandler
