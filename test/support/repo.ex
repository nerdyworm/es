defmodule ES.Repo do
  use Ecto.Repo, otp_app: :es
end

defmodule TestEventStore do
  use ES.EventStore, adapter: ES.Storage.Memory, inline: true, repo: ES.Repo
end

defmodule EventStore do
  use ES.EventStore, adapter: ES.Storage.Memory, inline: true, repo: ES.Repo
end
