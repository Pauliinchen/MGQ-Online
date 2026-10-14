#----------------------------------------------------------------
#  rgss_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Tests of rgss.rb and rpg.rb: the value classes pack as RGSS packs them, and the stand-ins for
# the screen keep their settings.

require_relative "support"
require_relative File.join(LIB_DIR, "compat")
require_relative File.join(LIB_DIR, "rgss")
require_relative File.join(LIB_DIR, "rpg")

# A Table as RGSS packs it: dimensions, sizes, count, then 16-bit values.
table = Table.new(3, 2)
table[1, 1] = 7
table[2, 0] = -5
table[0, 0] = 40_000
packed = Marshal.dump(table)
copy = Marshal.load(packed)
check("a table keeps its values through Marshal", [copy[1, 1], copy[2, 0]], [7, -5])
check("a table cuts values to 16 bits", copy[0, 0], 32_767)
check("a table outside its size reads nil", copy[3, 0], nil)
check("a table packs as RGSS: header of five 32-bit numbers", table._dump(0).unpack("l5"), [2, 3, 2, 1, 6])
table.resize(4, 3)
check("a resized table keeps the values that fit", [table[1, 1], table[3, 2]], [7, 0])

color = Marshal.load(Marshal.dump(Color.new(10, 20, 30)))
check("a color keeps its channels, alpha 255 when left out", [color.red, color.green, color.blue, color.alpha], [10.0, 20.0, 30.0, 255.0])
check("a color's channels stay within 0 and 255", Color.new(300, -4, 0).red, 255.0)
tone = Marshal.load(Marshal.dump(Tone.new(-300, 0, 10, 99)))
check("a tone keeps its channels within -255 and 255", [tone.red, tone.blue, tone.gray], [-255.0, 10.0, 99.0])

# The screen's stand-ins.
window = Window.new(1, 2, 30, 40)
window.openness = 300
check("a window's openness stays within 0 and 255", window.openness, 255)
check("a window is open at 255", window.open?, true)
bitmap = Bitmap.new(100, 50)
check("a bitmap keeps its size", [bitmap.width, bitmap.height], [100, 50])
check("a bitmap guesses a text's width from its font", bitmap.text_size("abcd").width, 4 * bitmap.font.size / 2)
Graphics.frame_count = 0
Graphics.wait(5)
check("waiting counts frames without waiting", Graphics.frame_count, 5)
check("nothing is pressed without a driver", [Input.press?(:C), Input.trigger?(:C), Input.dir4], [false, false, 0])
Input.drive(:C)
Input.update
check("a driven key counts as pressed for one frame", Input.trigger?(:C), true)
Input.update
check("and not the frame after", Input.trigger?(:C), false)

# The database's classes, as the RGSS3 reference defines them.
check("a class's EXP curve needs nothing for level 1", RPG::Class.new.exp_for_level(1), 0)
check("and grows with the level", RPG::Class.new.exp_for_level(10) < RPG::Class.new.exp_for_level(11), true)
skill = RPG::Skill.new
skill.scope = 2
check("all enemies is for opponents and everyone", [skill.for_opponent?, skill.for_all?, skill.need_selection?], [true, true, false])
damage = RPG::UsableItem::Damage.new
damage.type = 3
damage.formula = "a * 2"
check("a healing formula comes out negative", damage.eval(5, 0, nil), -10)
# As in RGSS3, only an error while it runs deals 0; a formula that does not even parse raises.
damage.formula = "a.no_such_stat * 2"
check("a formula failing as it runs deals 0", damage.eval(5, 0, nil), 0)
