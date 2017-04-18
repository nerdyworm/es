Code.require_file("test/es/stages/case.exs")
Code.require_file("test/es/storage/case.exs")
Mix.Task.run("ecto.drop", ~w(--quiet))
Mix.Task.run("ecto.create", ~w(--quiet))
Mix.Task.run("ecto.migrate", ~w(--quiet))
Mix.Ecto.ensure_repo(ES.Repo, [])
Mix.Ecto.ensure_started(ES.Repo, [])
{:ok, _} = TestEventStore.start_link
ExUnit.start()

