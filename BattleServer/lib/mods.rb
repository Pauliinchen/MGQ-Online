#----------------------------------------------------------------
#  mods.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Loaded a battle's mods through the Mod Framework's late load, which sets up their run wrappers and reads the database again
#      Paulinchen  2026-11-08: Downloaded a world's mods from the website's catalog and checked the package and each file against its hashes
#                            - Read the files of a version the starter names without them from the website's details of the mod
#      Paulinchen  2026-11-05: Read the mods a setup names without the core, moved from battles_served.rbx
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

require "digest"
require "fileutils"
require "json"
require "net/http"
require "stringio"
require "uri"
require "zlib"
require_relative "boot"

# The world's mods for a battle the server hosts. The starter names the website mods it runs with
# each file's hash as the website lists them (MGQ_MpWorldMods.served_mods), or without files for a
# version the website's list lacks, such as one a world is pinned to; the server takes them from
# its cache or downloads the version's package from the website's catalog, as the Mod Framework
# installs it, and keeps it only when the package and each of its files match the website's hashes
# and the starter's. A battle's child then loads them as Patch.rb would, inside its
# sandbox, and their other files read from memory as if they lay in Patch.
module ServedMods
  # The folder downloaded mods are kept in, outside the game folder, from BATTLE_MOD_CACHE.
  CACHE_DIR = File.expand_path(ENV["BATTLE_MOD_CACHE"] || File.join(__dir__, "..", "mod_cache"))

  # The website whose catalog the mods come from: mgqonline.org, or the one MGQ_MODS_SITE names, as
  # the Mod Framework reads it.
  SITE = ENV["MGQ_MODS_SITE"] || "https://mgqonline.org"

  # The query that asks the catalog for each platform's package.
  SCHEMA_QUERY = "?schema=3"

  # The platform whose package the server loads, the game's own scripts being the PC's.
  PLATFORM = "pc"

  # The kind of a mod the starter names that the website serves.
  SITE_KIND = "site"

  # Most bytes of a download, as the website takes a package.
  MAX_DOWNLOAD_BYTES = 64 * 1024 * 1024

  # Most files of a mod, and most bytes they unpack to, as the relay takes a zip.
  MAX_FILES = 100
  MAX_UNPACKED_BYTES = 64 * 1024 * 1024

  # Most redirects a download may take on its way, each within the website.
  MAX_REDIRECTS = 3

  # Seconds a download may take.
  DOWNLOAD_SECONDS = 60

  # A path inside Patch a mod's file may have: no step up, no drive, no start at the root.
  PATCH_PATH = %r{\A(?!/)(?!.*(?:\A|/)\.\.(?:/|\z))[^:\\]+\z}

  # The format of a setup whose mods named_in reads, MGQOnline.Game's ServedSetup.Format.
  SETUP_FORMAT = 1

  # The place of the world's mods among a setup's values.
  SETUP_MODS = 18

  # The escapes a setup's texts hold, turned back.
  SETUP_ESCAPES = { '\\\\' => "\\", '\t' => "\t", '\n' => "\n", '\r' => "\r" }.freeze

  # Raised when a battle's mods cannot all be had, which the starter hears as the refusal "mods".
  class Unavailable < StandardError; end

  class << self
    # Reads the world's mods a served battle's setup names.
    #
    # A battle's child gets its mods before its sandbox, which reaches neither the network nor the
    # cache, and may start the core only inside it, so this reads the setup, a battle line
    # MGQOnline.Game's ServedSetup writes, without the core: its texts, whole numbers and lists,
    # all the mods' place holds.
    #
    # @param setup [String] The setup.
    # @return [Array<Array>, nil] Each mod's key, kind (empty for one the server cannot get), version
    #   and files' hashes by path, those of another shape left out; nil for a setup of another format.
    def named_in(setup)
      values = setup_values(setup)
      return nil unless values && values[0] == SETUP_FORMAT && values[3].is_a?(Integer)

      Array(values[SETUP_MODS]).filter_map do |key, kind, version, files|
        next unless key.is_a?(String) && !key.empty? && kind.is_a?(String) && version.is_a?(String) && files.is_a?(Array)

        hashes = {}
        files.each { |path, hash| hashes[path] = hash if path.is_a?(String) && hash.is_a?(String) && hash.match?(/\A[0-9a-f]{64}\z/) }
        [key, kind, version, hashes]
      end
    end

    # Gets the files of a battle's mods: from the cache, else from the website's catalog.
    #
    # @param mods [Array<Array>] Each mod's slug, kind, version and files' hashes by path, see
    #   MGQ_MpWorldMods.served_mods; no hashes to take those the website's details list.
    # @param site [String, nil] The website, such as SITE; nil to read the cache only.
    # @param log [IO] Where downloads are noted.
    # @return [Array<Array(String, Hash)>] Each mod's slug and its files' bytes by path inside Patch.
    # @raise [Unavailable] For a mod the server cannot get in the starter's version.
    def fetch(mods, site, log = $stderr)
      mods.map do |slug, kind, version, hashes|
        raise Unavailable, "the starter's copy of #{slug} (#{version.empty? ? 'unknown version' : version}) is none the website serves" if kind != SITE_KIND

        package = nil
        if hashes.empty?
          raise Unavailable, "the starter names no files of #{slug} #{version}, and the server knows no website to read them from" unless site

          package, hashes = package_of(site, slug, version)
        end
        cached = read_cache(slug, hashes)
        next [slug, cached] if cached

        raise Unavailable, "#{slug} is not in the server's cache, and the server knows no website to fetch it from" unless site

        files = download(site, slug, version, hashes, package)
        write_cache(slug, hashes, files)
        log.puts("downloaded #{slug} #{version} from the website: #{files.size} file(s)")
        [slug, files]
      end
    end

    # Loads a battle's mods into the game, as Patch.rb loads the Patch folder's scripts: each
    # script in the order of its path, at the top level; the mods' other files read from memory.
    # They load through the Mod Framework's Mods.load_late, as the game loads mods on entering.
    #
    # Mods such as Invasions install their battle hooks only in a SceneManager.run wrapper, and the
    # server's SceneManager.run ran once at boot, before any world mod.
    #
    # @param mods [Array<Array(String, Hash)>] The mods, see fetch.
    # @param log [IO] Where a script or a run wrapper that fails is noted.
    # @return [Integer] How many scripts loaded.
    def load(mods, log = $stderr)
      # A process that hosts one battle after another (thread mode) keeps the mods it loaded.
      loaded = mods.map { |key, mod_files| [key, mod_files.keys.sort] }
      return 0 if @loaded == loaded

      @loaded = loaded
      files = {}
      mods.each { |_, mod_files| mod_files.each { |path, bytes| files["#{Boot::PATCH_DIR}/#{path}"] = bytes } }
      overlay(files)
      scripts = files.keys.select { |path| path.downcase.end_with?(".rb") }.sort
      Mod_Framework::Mods.load_late("the served battle") do
        run = SceneManager.singleton_class.instance_method(:run)
        scripts.each { |path| evaluate(path, files[path], log) }
        note_run_failures(run, log)
      end
      scripts.size
    end

    # Hashes a mod's file as the website lists it: SHA-256 of its bytes.
    #
    # @param bytes [String] The file.
    # @return [String] The hash as 64 lowercase hexadecimal characters.
    def hash_of(bytes)
      Digest::SHA256.hexdigest(bytes.b)
    end

    # Reads a zip's files: plain and deflated ones, a top Patch folder left out of their paths, as the
    # Mod Framework installs a package.
    #
    # @param bytes [String] The zip.
    # @return [Hash] Each file's bytes by its path inside Patch.
    # @raise [Unavailable] For a damaged zip or one past the limits.
    def unzip(bytes)
      bytes = bytes.b
      finish = bytes.rindex("PK\x05\x06".b)
      raise Unavailable, "the zip has no list of files" unless finish && finish + 22 <= bytes.bytesize

      count = bytes.byteslice(finish + 10, 2).unpack1("v")
      at = bytes.byteslice(finish + 16, 4).unpack1("V")
      files = {}
      unpacked = 0
      count.times do
        raise Unavailable, "the zip's list of files is damaged" unless at + 46 <= bytes.bytesize && bytes.byteslice(at, 4) == "PK\x01\x02".b

        method, = bytes.byteslice(at + 10, 2).unpack("v")
        packed, size, name_length, extra_length, comment_length = bytes.byteslice(at + 20, 14).unpack("VVvvv")
        local = bytes.byteslice(at + 42, 4).unpack1("V")
        name = bytes.byteslice(at + 46, name_length).force_encoding("UTF-8").tr("\\", "/").sub(%r{\APatch/}i, "")
        at += 46 + name_length + extra_length + comment_length
        next if name.empty? || name.end_with?("/")
        raise Unavailable, "the zip holds #{name[0, 80]}, which is no path inside Patch" unless name.valid_encoding? && name.match?(PATCH_PATH)

        unpacked += size
        raise Unavailable, "the zip holds more than #{MAX_FILES} files of #{MAX_UNPACKED_BYTES} bytes" if files.size >= MAX_FILES || unpacked > MAX_UNPACKED_BYTES

        files[name] = unpack(bytes, local, method, packed, size, name)
      end
      files
    end

    private

    # Evaluates one script of a mod at the top level, as Patch.rb does.
    #
    # @param path [String] The script's path from the game folder.
    # @param bytes [String] The script.
    # @param log [IO] Where a script that fails is noted.
    def evaluate(path, bytes, log)
      eval(bytes.dup.force_encoding("UTF-8").delete_prefix("﻿"), TOPLEVEL_BINDING, path, 1)
    rescue ScriptError, StandardError => e
      log.puts("mod script #{path}: #{e.class}: #{e.message.lines.first&.strip}")
    end

    # Puts one outermost wrapper on SceneManager.run once the mods wrapped it, which notes a
    # failure of their wrappers as the framework sets them up and raises it again.
    #
    # The framework logs that failure only to its own log file, which a sandboxed child may not
    # write; the wrapper goes when the framework restores the real run.
    #
    # @param run [UnboundMethod] SceneManager.run before the mods loaded.
    # @param log [IO] Where the failure is noted.
    def note_run_failures(run, log)
      owner = SceneManager.singleton_class
      wrapped = owner.instance_method(:run)
      return if wrapped == run

      owner.send(:define_method, :run) do |*args, &block|
        wrapped.bind(self).call(*args, &block)
      rescue StandardError => e
        log.puts("mod run setup: #{e.class}: #{e.message.lines.first&.strip}")
        raise
      end
    end

    # Reads a setup's values: tab-separated tokens, lists between "[" and "]".
    #
    # @param setup [String] The setup.
    # @return [Array, nil] The values, nil for brackets that do not close.
    def setup_values(setup)
      stack = [[]]
      setup.to_s.split("\t").each do |token|
        case token
        when "[" then stack.push([])
        when "]"
          return nil if stack.size < 2

          inner = stack.pop
          stack.last << inner
        else stack.last << setup_value(token)
        end
      end
      stack.size == 1 ? stack[0] : nil
    end

    # Reads one token of a setup.
    #
    # @param token [String] The token, its kind first.
    # @return [Integer, String, nil] A whole number, a text, nil for any other kind.
    def setup_value(token)
      case token[0]
      when "i" then Integer(token[1..], exception: false)
      when "s" then token[1..].gsub(/\\[\\tnr]/, SETUP_ESCAPES)
      end
    end

    # Unpacks one file of a zip.
    #
    # @param bytes [String] The zip.
    # @param local [Integer] Where the file's local header starts.
    # @param method [Integer] How it is packed: 0 plain, 8 deflated.
    # @param packed [Integer] Its packed size.
    # @param size [Integer] Its size.
    # @param name [String] Its path, for the error.
    # @return [String] The file.
    # @raise [Unavailable] For another method, a damaged file or one of another size.
    def unpack(bytes, local, method, packed, size, name)
      raise Unavailable, "the zip's #{name[0, 80]} is damaged" unless local + 30 <= bytes.bytesize && bytes.byteslice(local, 4) == "PK\x03\x04".b

      start = local + 30 + bytes.byteslice(local + 26, 4).unpack("vv").sum
      data = bytes.byteslice(start, packed).to_s
      data = case method
             when 0 then data
             when 8
               inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
               begin
                 inflater.inflate(data)
               ensure
                 inflater.close
               end
             else raise Unavailable, "the zip packs #{name[0, 80]} in a way the server does not read"
             end
      raise Unavailable, "the zip's #{name[0, 80]} is damaged" unless data.bytesize == size

      data
    rescue Zlib::Error
      raise Unavailable, "the zip's #{name[0, 80]} is damaged"
    end

    # Downloads a mod's version from the website: its package, checked against the website's hash,
    # whose files must be those the website lists and the starter names.
    #
    # @param site [String] The website.
    # @param slug [String] The mod's slug.
    # @param version [String] The starter's version.
    # @param hashes [Hash] The starter's files' hashes by path.
    # @param package [Hash, nil] The version's package as package_of read it with those hashes; nil
    #   to read it here.
    # @return [Hash] The files' bytes by path.
    # @raise [Unavailable] For a version the website does not serve, or a package or file that differs.
    def download(site, slug, version, hashes, package = nil)
      unless package
        package, listed = package_of(site, slug, version)
        raise Unavailable, "the website serves #{slug} #{version} with other files than the starter's" unless listed == hashes
      end

      bytes = get(URI.join(site, package["url"].to_s), site, redirects: MAX_REDIRECTS)
      raise Unavailable, "#{slug} #{version}'s package differs from the website's hash" unless Digest::SHA256.hexdigest(bytes) == package["sha256"].to_s.downcase

      files = unzip(bytes)
      raise Unavailable, "#{slug} #{version}'s files are not the website's" unless files.keys.sort == hashes.keys.sort && files.all? { |path, file| hash_of(file) == hashes[path] }

      files
    end

    # Reads a mod's version from the website's catalog: its package for PLATFORM and its files.
    #
    # @param site [String] The website.
    # @param slug [String] The mod's slug.
    # @param version [String] The version.
    # @return [Array(Hash, Hash)] The package ("url", "sha256") and its files' hashes by path inside Patch.
    # @raise [Unavailable] When the website does not list the version with a package.
    def package_of(site, slug, version)
      details = JSON.parse(get(URI.join(site, "/api/mods/#{URI.encode_www_form_component(slug)}#{SCHEMA_QUERY}"), site))
      listed = Array(details.is_a?(Hash) && details["mod"].is_a?(Hash) ? details["mod"]["versions"] : nil).find { |each| each.is_a?(Hash) && each["version"] == version }
      raise Unavailable, "the website does not list #{slug} #{version}" unless listed

      package = Array(listed["packages"]).find { |each| each.is_a?(Hash) && each["platform"] == PLATFORM }
      package ||= listed["package"].is_a?(Hash) ? listed["package"].merge("files" => listed["files"]) : nil
      raise Unavailable, "the website has no package of #{slug} #{version}" unless package.is_a?(Hash) && package["url"].is_a?(String)

      files = Array(package["files"]).select { |file| file.is_a?(Hash) }.to_h { |file| [file["path"].to_s.tr("\\", "/").sub(%r{\APatch/}i, ""), file["sha256"].to_s.downcase] }
      [package, files]
    rescue JSON::ParserError
      raise Unavailable, "the website's details of #{slug} are no JSON"
    end

    # Downloads a file from the website, following redirects within it only.
    #
    # @param uri [URI] The address.
    # @param site [String] The website, whose host a redirect must keep.
    # @param redirects [Integer] How many redirects it may still take.
    # @return [String] The file.
    # @raise [Unavailable] When it could not be downloaded or lies elsewhere.
    def get(uri, site, redirects: 0)
      host = URI(site).host
      raise Unavailable, "#{uri} is not on the website" unless uri.host == host && %w[http https].include?(uri.scheme)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: DOWNLOAD_SECONDS) do |http|
        http.request(Net::HTTP::Get.new(uri)) do |answer|
          next unless answer.is_a?(Net::HTTPSuccess)

          body = +""
          answer.read_body do |chunk|
            body << chunk
            raise Unavailable, "#{uri.host} sent more than #{MAX_DOWNLOAD_BYTES} bytes" if body.bytesize > MAX_DOWNLOAD_BYTES
          end
          answer.instance_variable_set(:@kept_body, body)
        end
      end
      return response.instance_variable_get(:@kept_body).to_s if response.is_a?(Net::HTTPSuccess)
      return get(URI.join(uri, response["location"].to_s), site, redirects: redirects - 1) if response.is_a?(Net::HTTPRedirection) && redirects.positive?

      raise Unavailable, "#{uri.host} answered #{response.code}"
    rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => e
      raise Unavailable, "#{uri.host} could not be reached: #{e.message}"
    end

    # Finds a mod's folder in the cache, by its key and its files' hashes.
    #
    # @param key [String] The mod's key.
    # @param hashes [Hash] Its files' hashes by path.
    # @return [String] The folder.
    def cache_dir(key, hashes)
      File.join(CACHE_DIR, Digest::SHA256.hexdigest(key)[0, 16], Digest::SHA256.hexdigest(JSON.generate(hashes.sort))[0, 32])
    end

    # Reads a mod from the cache, each file checked against its hash again.
    #
    # @param key [String] The mod's key.
    # @param hashes [Hash] Its files' hashes by path.
    # @return [Hash, nil] The files' bytes by path, nil while the cache lacks or spoils one.
    def read_cache(key, hashes)
      dir = cache_dir(key, hashes)
      files = hashes.to_h { |path, _| [path, File.binread(File.join(dir, path))] }
      files.all? { |path, bytes| hash_of(bytes) == hashes[path] } ? files : nil
    rescue SystemCallError, IOError
      nil
    end

    # Keeps a mod in the cache, written aside first so another battle never reads half of it.
    #
    # @param key [String] The mod's key.
    # @param hashes [Hash] Its files' hashes by path.
    # @param files [Hash] The files' bytes by path.
    def write_cache(key, hashes, files)
      dir = cache_dir(key, hashes)
      aside = "#{dir}.#{Process.pid}.part"
      files.each do |path, bytes|
        target = File.join(aside, path)
        make_dirs(File.dirname(target))
        write_file(target, bytes)
      end
      make_dirs(File.dirname(dir))
      File.rename(aside, dir)
    rescue SystemCallError
      # Another battle cached the same mod meanwhile, or the cache cannot be written: the files
      # in memory serve this battle either way.
      FileUtils.rm_rf(aside) if aside
    end

    # Writes a file of the cache, past the game's guard that discards every write (see Boot).
    #
    # @param path [String] The file.
    # @param bytes [String] Its bytes.
    def write_file(path, bytes)
      writer = Boot::Wrap.original(File.singleton_class, :binwrite, :discard)
      writer ? File.send(writer, path, bytes) : File.binwrite(path, bytes)
    end

    # Makes a folder of the cache and the folders above it, past the game's guard that makes no
    # folder (see Boot).
    #
    # @param dir [String] The folder.
    def make_dirs(dir)
      return if File.directory?(dir) || File.dirname(dir) == dir

      make_dirs(File.dirname(dir))
      maker = Boot::Wrap.original(Dir.singleton_class, :mkdir, :discard)
      maker ? Dir.send(maker, dir) : Dir.mkdir(dir)
    rescue Errno::EEXIST
      nil
    end

    # Lets the game read the mods' files as if they lay in Patch: File's reads of those paths come
    # from memory.
    #
    # @param files [Hash] Each file's bytes by its path from the game folder, such as "Patch/A/b.txt".
    def overlay(files)
      @files = files
      return if @overlaid

      @overlaid = true
      file = File.singleton_class
      %i[exist? file?].each do |name|
        Boot::Wrap.around(file, name, :mods) { |_owner, original, args, _block| ServedMods.file?(args[0]) || original.call(*args) }
      end
      %i[read binread].each do |name|
        Boot::Wrap.around(file, name, :mods) do |_owner, original, args, _block|
          bytes = ServedMods.bytes_of(args[0])
          next original.call(*args) unless bytes

          name == :read && args.last.is_a?(Hash) && args.last[:encoding].to_s.include?("UTF-8") ? bytes.dup.force_encoding("UTF-8").delete_prefix("﻿") : bytes.dup
        end
      end
      Boot::Wrap.around(file, :size, :mods) { |_owner, original, args, _block| ServedMods.bytes_of(args[0])&.bytesize || original.call(*args) }
      Boot::Wrap.around(file, :open, :mods) do |_owner, original, args, block|
        bytes = Boot.writing?(args[1]) ? nil : ServedMods.bytes_of(args[0])
        next original.call(*args, &block) unless bytes

        io = StringIO.new(bytes.dup)
        block ? block.call(io) : io
      end
    end

    public

    # Tells whether a path names one of the battle's mod files.
    #
    # @param path [Object] The path.
    # @return [Boolean] Whether it does.
    def file?(path)
      !bytes_of(path).nil?
    end

    # Finds one of the battle's mod files by its path.
    #
    # @param path [Object] The path, from the game folder.
    # @return [String, nil] The file's bytes, nil for a path that names none.
    def bytes_of(path)
      return nil unless @files && (path.is_a?(String) || path.respond_to?(:to_path))

      @files[path.to_s.tr("\\", "/").delete_prefix("./")]
    end
  end
end
