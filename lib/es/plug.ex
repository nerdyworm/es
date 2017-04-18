defmodule ES.Plug do
  alias ES.Plug.Router

  def init(options) do
    options
  end

  def call(conn, opts) do
    namespace = opts[:namespace] || "dq"
    Plug.Conn.assign(conn, :namespace, namespace)
    |> namespace(opts, namespace)
  end

  def namespace(%Plug.Conn{path_info: [ns | path]} = conn, opts, ns) do
    Router.call(%Plug.Conn{conn | path_info: path}, Router.init(opts))
  end
end

