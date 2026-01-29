defmodule YoutubeVideoChatApp.Accounts do
  @moduledoc """
  The Accounts context - simplified user management for demo
  """
  
  # Generate a random guest user
  def create_guest_user do
    %{
      id: Ecto.UUID.generate(),
      username: "Guest#{:rand.uniform(9999)}",
      color: random_color()
    }
  end
  
  defp random_color do
    colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E2"]
    Enum.random(colors)
  end
end
