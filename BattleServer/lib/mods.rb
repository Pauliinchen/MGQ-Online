#----------------------------------------------------------------
#  mods.rb
#
#  Changelog:
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

# The world's mods for a battle the server hosts. The starter names the mods it runs with each
# file's hash (MGQ_MpWorldMods.served_mods); the server takes them from its cache or downloads
# them from the relay's catalog as the games do, from the admins' GitHub releases or the relay's
# uploads, and keeps only files whose hashes match. A battle's child then loads them as Patch.rb
# would, inside its sandbox, and their other files read from memory as if they lay in Patch.
module ServedMods
  # The folder downloaded mods are kept in, outside the game folder, from BATTLE_MOD_CACHE.
  CACHE_DIR = File.expand_path(ENV["BATTLE_MOD_CACHE"] || File.join(__dir__, "..", "mod_cache"))

  # Most bytes of a download, as the relay takes an upload.
  MAX_DOWNLOAD_BYTES = 16 * 1024 * 1024

  # Most files of a mod, and most bytes they unpack to, as the relay takes a zip.
  MAX_FILES = 100
  MAX_UNPACKED_BYTES = 64 * 1024 * 1024

  # Most redirects a release file may take on its way.
  MAX_REDIRECTS = 3

  # Seconds a download may take.
  DOWNLOAD_SECONDS = 60

  # What the server tells the relay of itself, as every game does, which the relay's gate reads:
  # Raid Worlds, and the version of its MGQ Online from BATTLE_MGQ_VERSION, a development build's
  # unless named.
  RELAY_HEADERS = { "X-MGQ-Features" => "raid", "X-MGQ-Version" => ENV["BATTLE_MGQ_VERSION"] || "0.0.0-dev" }.freeze

  # Where a link mod's release file must lie: the admins' GitHub releases.
  RELEASE_FILE = %r{\Ahttps://github\.com/[^/]+/[^/]+/releases/download/}

  # The hosts GitHub serves release files from, which a release file may redirect to.
  FILE_HOSTS = %w[objects.githubusercontent.com release-assets.githubusercontent.com].freeze

  # A path inside Patch a mod's file may have: no step up, no drive, no start at the root.
  PATCH_PATH = %r{\A(?!/)(?!.*(?:\A|/)\.\.(?:/|\z))[^:\\]+\z}

  # Raised when a battle's mods cannot all be had, which the starter hears as the refusal "mods".
  class Unavailable < StandardError; end

  class << self
    # Gets the files of a battle's mods: from the cache, else from the relay's catalog.
    #
    # @param mods [Array<Array>] Each mod's key, kind, version and files' hashes by path, see
    #   MGQ_MpBattlesServed.mods_of.
    # @param relay [String, nil] The relay's address for its catalog, such as http://127.0.0.1:8080.
    # @param log [IO] Where downloads are noted.
    # @return [Array<Array(String, Hash)>] Each mod's key and its files' bytes by path inside Patch.
    # @raise [Unavailable] For a mod the server cannot get in the starter's version.
    def fetch(mods, relay, log = $stderr)
      catalog = nil
      mods.map do |key, kind, version, hashes|
        raise Unavailable, "the starter's copy of #{key} (#{version.empty? ? 'unknown version' : version}) is none the catalog serves" if kind.empty? || hashes.empty?

        cached = read_cache(key, hashes)
        next [key, cached] if cached

        raise Unavailable, "#{key} is not in the server's cache, and the server knows no relay to fetch it from" unless relay

        catalog ||= catalog_of(relay)
        files = download(catalog, key, hashes, relay)
        write_cache(key, hashes, files)
        log.puts("downloaded #{key} #{version}: #{files.size} file(s)")
        [key, files]
      end
    end

    # Loads a battle's mods into the game, as Patch.rb loads the Patch folder's scripts: each
    # script in the order of its path, at the top level; the mods' other files read from memory.
    #
    # @param mods [Array<Array(String, Hash)>] The mods, see fetch.
    # @param log [IO] Where a script that fails is noted.
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
      scripts.each do |path|
        source = files[path].dup.force_encoding("UTF-8").delete_prefix("﻿")
        begin
          eval(source, TOPLEVEL_BINDING, path, 1)
        rescue ScriptError, StandardError => e
          log.puts("mod script #{path}: #{e.class}: #{e.message.lines.first&.strip}")
        end
      end
      scripts.size
    end

    # Hashes a mod's file as the catalog does: SHA-256, a script without its carriage returns.
    #
    # @param path [String] The file's path or name.
    # @param bytes [String] The file.
    # @return [String] The hash as 64 lowercase hexadecimal characters.
    def hash_of(path, bytes)
      Digest::SHA256.hexdigest(path.downcase.end_with?(".rb") ? bytes.b.delete("\r") : bytes.b)
    end

    # Reads a zip's files: plain and deflated ones, as the relay reads them, a top Patch folder left
    # out of their paths.
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

    # Reads the relay's catalog.
    #
    # @param relay [String] The relay's address.
    # @return [Array<Hash>] Its mods as it lists them.
    # @raise [Unavailable] When the relay could not be asked.
    def catalog_of(relay)
      body = get(URI.join(relay, "/v1/mods"))
      mods = JSON.parse(body)["mods"]
      raise Unavailable, "the relay's catalog lists no mods" unless mods.is_a?(Array)

      mods
    rescue JSON::ParserError
      raise Unavailable, "the relay's catalog is no JSON"
    end

    # Downloads a mod in the starter's version, as the games do, and keeps only files whose
    # hashes match.
    #
    # @param catalog [Array<Hash>] The relay's catalog.
    # @param key [String] The mod's key.
    # @param hashes [Hash] The starter's files' hashes by path.
    # @param relay [String] The relay's address.
    # @return [Hash] The files' bytes by path.
    # @raise [Unavailable] For a mod the catalog lacks, serves in another version, or whose files differ.
    def download(catalog, key, hashes, relay)
      mod = catalog.find { |entry| entry.is_a?(Hash) && entry["key"] == key }
      raise Unavailable, "the catalog lacks #{key}" unless mod
      raise Unavailable, "the catalog serves #{key} #{mod['version']}, not the starter's version" unless mod["files"] == hashes

      files = case mod["kind"]
              when "upload" then unzip(get(URI.join(relay, "/v1/mods/#{URI.encode_www_form_component(key)}/file")))
              when "link", "zip" then release(mod)
              else raise Unavailable, "#{key} is a mod the catalog names but serves no file of"
              end
      raise Unavailable, "#{key}'s files are not the catalog's" unless files.keys.sort == hashes.keys.sort && files.all? { |path, bytes| hash_of(path, bytes) == hashes[path] }

      files
    end

    # Downloads a link mod's release file: a script, or a zip of its files.
    #
    # @param mod [Hash] The catalog's mod.
    # @return [Hash] The files' bytes by path.
    # @raise [Unavailable] For a release file outside the admins' GitHub.
    def release(mod)
      url = mod["fileUrl"].to_s
      raise Unavailable, "#{mod['key']}'s release file lies outside GitHub's releases" unless url.match?(RELEASE_FILE)

      bytes = get(URI(url), redirects: MAX_REDIRECTS)
      return unzip(bytes) if mod["archive"] == true

      { mod["files"].keys.first => bytes }
    end

    # Downloads a file, following redirects to GitHub's file hosts only.
    #
    # @param uri [URI] The address.
    # @param redirects [Integer] How many redirects it may still take.
    # @return [String] The file.
    # @raise [Unavailable] When it could not be downloaded.
    def get(uri, redirects: 0)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: DOWNLOAD_SECONDS) do |http|
        # GitHub's hosts get no word of the relay's headers.
        headers = FILE_HOSTS.include?(uri.host) || uri.host == "github.com" ? {} : RELAY_HEADERS
        http.request(Net::HTTP::Get.new(uri, headers)) do |answer|
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

      if response.is_a?(Net::HTTPRedirection) && redirects.positive?
        target = URI.join(uri, response["location"].to_s)
        raise Unavailable, "a release file redirects to #{target.host}" unless target.scheme == "https" && FILE_HOSTS.include?(target.host)

        return get(target, redirects: redirects - 1)
      end
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
      files.all? { |path, bytes| hash_of(path, bytes) == hashes[path] } ? files : nil
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
