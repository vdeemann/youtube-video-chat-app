defmodule YoutubeVideoChatApp.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring access to the
  application's data layer.

  If the test case interacts with the database, we enable the SQL sandbox,
  so changes done to the database are reverted at the end of every test.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias YoutubeVideoChatApp.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import YoutubeVideoChatApp.DataCase
    end
  end

  setup tags do
    YoutubeVideoChatApp.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(YoutubeVideoChatApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
