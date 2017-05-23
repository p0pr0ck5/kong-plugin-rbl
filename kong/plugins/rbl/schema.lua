return {
  fields = {
    concurrent_queries = { type = "number", required = true, default = 1 },
    rbl_srvs = { type = "array", required = true },
    nameservers = { type = "array", required = true },
    cache_ttl = { type = "number", required = true },
    lock_timeout = { type = "number", default = 1 },
    txt_followup = { type = "boolean", default = false },
  },
}
