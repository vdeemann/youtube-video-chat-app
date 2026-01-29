# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     YoutubeVideoChatApp.Repo.insert!(%YoutubeVideoChatApp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias YoutubeVideoChatApp.{Rooms, Accounts, Repo}
alias YoutubeVideoChatApp.Rooms.Room

# Create a sample room for development
# First check if the demo room already exists
case Repo.get_by(Room, slug: "demo-room") do
  nil ->
    # Room doesn't exist, create it
    user = Accounts.create_guest_user()
    
    {:ok, room} = Rooms.create_room(%{
      name: "Demo Watch Party",
      slug: "demo-room",
      host_id: user.id,
      is_public: true,
      current_video_id: "jNQXAC9IVRw", # "Me at the zoo" - First YouTube video
      queue: []
    })
    
    IO.puts "Created demo room: /room/#{room.slug}"
    
  room ->
    # Room already exists
    IO.puts "Demo room already exists: /room/#{room.slug}"
end

IO.puts "\n✅ Seeds completed successfully!"
