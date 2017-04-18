use Mix.Config

config :es, :token, "xxxx"

config :es, ecto_repos: [ES.Repo]

config :es, ES.Repo,[
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "wispy_test",
  hostname: "localhost",
  #pool: Ecto.Adapters.SQL.Sandbox
]

