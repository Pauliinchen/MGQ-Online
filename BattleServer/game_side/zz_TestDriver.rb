#----------------------------------------------------------------
#  zz_TestDriver.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

# A test-only driver for the battle server's comparison with the real game; never in a repo and
# removed after the test. Every 10 frames it runs each TestDriver/in/*.rb once, in name order,
# and writes what it returned (or the error) to TestDriver/out/<name>.txt.
module ZZTestDriver
  # The driver's folder in the game folder.
  DIR = "TestDriver"

  @frames = 0

  # Runs the waiting command files, every 10th frame.
  def self.poll
    @frames += 1
    return unless @frames % 10 == 0

    Dir.glob("#{DIR}/in/*.rb").sort.each do |path|
      name = File.basename(path, ".rb")
      code = File.read(path)
      File.delete(path)
      result = begin
        eval(code, TOPLEVEL_BINDING, path).inspect
      rescue Exception => e
        "ERROR #{e.class}: #{e.message}\n#{(e.backtrace || [])[0, 10].join("\n")}"
      end
      File.open("#{DIR}/out/#{name}.txt", "wb") { |file| file.write(result.to_s) }
    end
  rescue Exception => e
    File.open("#{DIR}/out/driver_error.txt", "wb") { |file| file.write("#{e.class}: #{e.message}") } rescue nil
  end
end

class << Graphics
  alias zz_test_driver_update update

  # Updates the screen, then runs the driver's commands.
  def update
    zz_test_driver_update
    ZZTestDriver.poll
  end
end
