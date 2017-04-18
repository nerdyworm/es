defmodule ES.Plug.Router do
  use Plug.Router


  # TODO - remove me :)
  def namespace(%Plug.Conn{path_info: ["dq" | path]} = conn, opts) do
    ES.Plug.Router.call(%Plug.Conn{conn | path_info: path}, ES.Plug.Router.init(opts))
  end

  def namespace(conn, _opts) do
    conn
  end

  plug :namespace
  plug CORSPlug, headers: ["*"]
  plug Plug.Parsers, parsers: [:json], json_decoder: Poison
  plug :auth
  plug :match
  plug :dispatch

  def start_link do
    Plug.Adapters.Cowboy.http(ES.Plug.Router, [])
  end

  def init(opts) do
    opts
  end

  def auth(conn, _opts) do
    incoming = get_req_header(conn, "x-dq-authorization") # TODO - configure me
    token    = Application.get_env(:es, :token, "")
    if "#{incoming}" == "#{token}" do
      conn
    else
      conn
      |> send_resp(403, "Invalid token")
      |> halt
    end
  end

  get "/api/ping" do
    conn
    |> send_resp(200, "ok")
    |> halt
  end

  get "/api/subscriptions" do
    subscriptions = Application.get_env(:es, :subscriptions, [])

    data =
      Enum.map(subscriptions, fn(subscription) ->
        {:ok, info} = subscription.info()

        %{
          id: "#{subscription}",
          type: "subscription",
          attributes: Map.merge(%{
            name: "#{subscription}"
          }, Map.delete(info, :__struct__))
        }
      end)

    json(conn, 200, %{data: data})
  end

  get "/api/subscriptions/:name" do
    queue = name |> String.to_existing_atom
    {:ok, info} = queue.info

    data = %{
      id: name,
      type: "subscription",
      attributes: Map.merge(%{
        name: "#{name}"
      }, Map.delete(info, :__struct__))
    }

    json(conn, 200, %{data: data})
  end

  put "/api/queues/:name/dead_purge" do
    queue = name |> String.to_existing_atom
    :ok = queue.dead_purge

    conn
    |> send_resp(204, "")
    |> halt
  end

  #put "/api/jobs/:job_id/retry" do
    #[name, _job_id] = String.split(job_id, "$$")
    #queue = name |> String.to_atom

    #job = queue.decode(conn.params["encoded"])
    #:ok = queue.dead_retry(job)

    #conn
    #|> send_resp(204, "")
    #|> halt
  #end

  #put "/api/jobs/:job_id/ack" do
    #[name, job_id] = String.split(job_id, "$$")
    #queue = name |> String.to_atom

    #job = queue.decode(conn.params["encoded"])
    #:ok = queue.dead_ack(job)

    #conn
    #|> send_resp(204, "")
    #|> halt
  #end

  get "/api/jobs" do
    queue = conn.params["queue_id"] |> String.to_existing_atom

    {:ok, dead} = queue.dead
    data = Enum.map(dead, fn(job) ->
      %{
        id: "#{queue}$$#{job.id}",
        type: "job",
        attributes: %{
          module: job.module,
          args: job.args,
          status: job.status,
          error_count: job.error_count,
          error_message: job.error_message,
          encoded: queue.encode(job)
        },
        relationships: %{
          queue: %{
            data: %{
              id: "#{queue}",
              type: "queue",
            }
          }
        }
      }
    end)

    included = [%{
      id: "#{queue}",
      type: "queue",
      attributes: %{
        name: "#{queue}"
      }
    }]

    json(conn, 200, %{data: data, included: included})
  end

  def json(conn, code, body) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(code, Poison.encode!(body))
    |> halt
  end
end
