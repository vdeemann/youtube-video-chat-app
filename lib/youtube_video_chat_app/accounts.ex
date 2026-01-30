defmodule YoutubeVideoChatApp.Accounts do
  @moduledoc """
  The Accounts context - user management and authentication.
  """
  
  import Ecto.Query, warn: false
  alias YoutubeVideoChatApp.Repo
  alias YoutubeVideoChatApp.Accounts.{User, UserToken}

  ## User Registration

  @doc """
  Registers a user.
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false, validate_username: false)
  end

  ## User Queries

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by id, returns nil if not found.
  """
  def get_user(id), do: Repo.get(User, id)

  ## Session Management

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Guest User Support
  
  @doc """
  Generate a random guest user (not persisted).
  """
  def create_guest_user do
    %{
      id: Ecto.UUID.generate(),
      username: "Guest#{:rand.uniform(9999)}",
      color: random_color(),
      is_guest: true
    }
  end

  @doc """
  Convert a registered user to the format used in rooms.
  """
  def user_to_room_user(%User{} = user) do
    %{
      id: user.id,
      username: user.username,
      color: user.color,
      is_guest: false
    }
  end
  
  defp random_color do
    colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E2"]
    Enum.random(colors)
  end
end
