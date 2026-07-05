defmodule YoutubeVideoChatApp.AudioAnalysisTest do
  use YoutubeVideoChatApp.DataCase

  alias YoutubeVideoChatApp.AudioAnalysis

  @result %{
    "key" => "A",
    "scale" => "minor",
    "key_strength" => 0.87,
    "bpm" => 120.3,
    "chords" => [%{"t" => 0.0, "c" => "Am"}, %{"t" => 4.5, "c" => "F"}]
  }

  describe "complete/3 and get/2" do
    test "caches a completed analysis keyed by media type + id" do
      {:ok, _} = AudioAnalysis.complete("youtube", "abc12345678", @result)

      analysis = AudioAnalysis.get("youtube", "abc12345678")
      assert analysis.status == "complete"
      assert analysis.key == "A"
      assert analysis.scale == "minor"
      assert analysis.bpm == 120.3
      assert analysis.chords["segments"] == @result["chords"]
    end

    test "broadcasts the payload on the track_analysis topic" do
      AudioAnalysis.subscribe()
      {:ok, _} = AudioAnalysis.complete("youtube", "abc12345678", @result)

      assert_receive {:track_analysis, payload}
      assert payload.media_id == "abc12345678"
      assert payload.key == "A"
      assert payload.bpm == 120
      assert payload.chords == @result["chords"]
    end

    test "upserts over an existing row instead of raising" do
      {:ok, _} = AudioAnalysis.mark_pending("youtube", "abc12345678")
      {:ok, _} = AudioAnalysis.complete("youtube", "abc12345678", @result)

      assert AudioAnalysis.get("youtube", "abc12345678").status == "complete"
    end

    test "get returns nil for unknown or malformed keys" do
      assert AudioAnalysis.get("youtube", "nope") == nil
      assert AudioAnalysis.get(nil, nil) == nil
    end
  end

  describe "fail/3" do
    test "stores a truncated error and does not broadcast" do
      AudioAnalysis.subscribe()
      {:ok, _} = AudioAnalysis.fail("youtube", "failvid1234", String.duplicate("x", 600))

      analysis = AudioAnalysis.get("youtube", "failvid1234")
      assert analysis.status == "failed"
      assert String.length(analysis.error) == 500
      refute_receive {:track_analysis, _}
    end
  end

  describe "payload/1" do
    test "is nil for pending, failed, and missing analyses" do
      {:ok, pending} = AudioAnalysis.mark_pending("youtube", "pend1234567")
      {:ok, failed} = AudioAnalysis.fail("youtube", "fail1234567", "boom")

      assert AudioAnalysis.payload(pending) == nil
      assert AudioAnalysis.payload(failed) == nil
      assert AudioAnalysis.payload(nil) == nil
    end
  end

  describe "get_payloads/1" do
    test "returns only complete analyses, keyed by {type, id}" do
      {:ok, _} = AudioAnalysis.complete("youtube", "done1234567", @result)
      {:ok, _} = AudioAnalysis.mark_pending("youtube", "pend1234567")

      payloads =
        AudioAnalysis.get_payloads([
          {"youtube", "done1234567"},
          {"youtube", "pend1234567"},
          {"soundcloud", "missing0000"}
        ])

      assert Map.keys(payloads) == [{"youtube", "done1234567"}]
      assert payloads[{"youtube", "done1234567"}].key == "A"
    end

    test "handles an empty key list without querying" do
      assert AudioAnalysis.get_payloads([]) == %{}
    end
  end

  describe "source_url/3" do
    test "builds a watch URL from YouTube video IDs" do
      assert AudioAnalysis.source_url("youtube", "dQw4w9WgXcQ", nil) ==
               "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    end

    test "uses the original URL for SoundCloud (media_id is a hash)" do
      assert AudioAnalysis.source_url("soundcloud", "ABC123", "https://soundcloud.com/a/b") ==
               "https://soundcloud.com/a/b"
    end

    test "returns nil when no source is resolvable" do
      assert AudioAnalysis.source_url("soundcloud", "ABC123", nil) == nil
      assert AudioAnalysis.source_url("bandcamp", "x", nil) == nil
    end
  end
end
