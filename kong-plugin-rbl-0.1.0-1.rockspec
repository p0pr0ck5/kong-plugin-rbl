package = "kong-plugin-rbl"
version = "0.1.0-1"

source = {
  url = "git://github.com/Mashape/kong_plugin",
  tag = "0.1.0"
}

supported_platforms = {"linux", "macosx"}
description = {
  summary = "Kong is a scalable and customizable API Management Layer built on top of Nginx.",
  homepage = "http://getkong.org",
  license = "MIT"
}

local pluginName = "rbl"
build = {
  type = "builtin",
  modules = {
    ["kong.plugins."..pluginName..".handler"] = "kong/plugins/"..pluginName.."/handler.lua",
    ["kong.plugins."..pluginName..".schema"] = "kong/plugins/"..pluginName.."/schema.lua",
  }
}
