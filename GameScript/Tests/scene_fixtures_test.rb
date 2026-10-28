#----------------------------------------------------------------
#  scene_fixtures_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Checks the stand-in of the story scene's queue and checks (scene_support.rb), which the script
# tests answer the DLL's topics with, against the golden cases in fixtures/scene, which
# MGQOnline.Game.Tests checks the C# classes against too, so the stand-in never drifts from the DLL.

require_relative "support"
require_relative "../../fixtures/wire/wire_harness"
require_relative "scene_support"

failure =
  begin
    check_scene_stand_in
    nil
  rescue => e
    e.message
  end
check("the scene stand-in answers every golden case of the queue and the checks as the DLL does", failure, nil)
