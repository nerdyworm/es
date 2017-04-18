# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :es, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:es, :key)
#
# Or configure a 3rd-party app:
#
    #config :logger, level: :warn
    config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
config :es, [
  idle_ms: 2000,             # how long to wait after we get nothing back from db
  cache_ttl: 60 * 5,         # how long to keep aggregates cached for in minutes
]

import_config "#{Mix.env}.exs"

