//----------------------------------------------------------------
//  mods.js
//
//  Changelog:
//      Paulinchen  2026-10-06: Took a zip of a release too, laid out as in Patch, hashing each file inside
//                            - Created
//
//----------------------------------------------------------------

// The catalog of mods a world may require, the same on every server. Only the relay's admins add
// mods: a single script or a zip laid out as in the game's Patch folder, by a download link on the
// admins' GitHub, whose releases the relay checks on a schedule, or a mod of several files that an
// admin uploads. The relay keeps a link mod's
// hash and version only, never the script, and never runs anything it reads. Games compare their
// installed files with the catalog's hashes and download what differs, checking every hash.

import { playerIdOf } from "./directory.js";

/**
 * The limits the catalog keeps.
 */
export const MOD_LIMITS = Object.freeze({
  maxMods: 100,
  maxNameLength: 32,
  maxVersionLength: 32,
  maxVersions: 20,
  maxFiles: 100,
  maxPathLength: 120,
  maxLinkBytes: 2 * 1024 * 1024,
  maxUploadBytes: 16 * 1024 * 1024,
  maxUnpackedBytes: 64 * 1024 * 1024,
  maxRedirects: 3,
});

/**
 * The only place a link may point to: the admins' GitHub.
 */
export const LINK_START = "https://github.com/Pauliinchen/";

/**
 * A release file on the admins' GitHub, a script or a zip, with the release's tag and the file's name.
 */
const RELEASE_FILE = /^https:\/\/github\.com\/Pauliinchen\/[A-Za-z0-9._-]+\/releases\/download\/([^/?#]+)\/([^/?#]+\.(?:rb|zip))$/i;

/**
 * The hosts GitHub serves release files from, which a release file's address may redirect to.
 */
export const FILE_HOSTS = Object.freeze(["objects.githubusercontent.com", "release-assets.githubusercontent.com"]);

/**
 * A player's key: 32 lowercase hexadecimal characters.
 */
const PLAYER_KEY = /^[0-9a-f]{32}$/;

/**
 * A file's hash: 64 lowercase hexadecimal characters.
 */
const HASH = /^[0-9a-f]{64}$/;

/**
 * A path inside the game's Patch folder: forward slashes, no step up, no drive, no start at the root.
 */
const PATCH_PATH = /^(?!\/)(?!.*(?:^|\/)\.\.?(?:\/|$))[^\\:*?"<>|\u0000-\u001f]+$/;

/**
 * Characters a name or version may not hold.
 */
const BREAKERS = /[\u0000-\u001f\u007f]/g;

/**
 * Turns a mod's name or its script's file name into what the two are compared by, as the games do.
 *
 * @param {string} name The name.
 * @returns {string} The name in lower case, without ".rb", spaces, underscores and hyphens.
 */
export function modKey(name) {
  return String(name).toLowerCase().replace(/\.rb$/, "").replace(/[\s_-]/g, "");
}

/**
 * Hashes a mod's file with SHA-256. A script is hashed without its carriage returns, so the same
 * script checked out on Windows and served by GitHub hashes the same.
 *
 * @param {string} path The file's path or name.
 * @param {Uint8Array} bytes The file.
 * @returns {Promise<string>} The hash as 64 lowercase hexadecimal characters.
 */
export async function hashModFile(path, bytes) {
  const data = path.toLowerCase().endsWith(".rb") ? bytes.filter((byte) => byte !== 13) : bytes;
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

/**
 * @typedef {object} ModStore Where the catalog keeps its mods and the files of uploaded ones.
 * @property {(key: string) => Promise<object | undefined>} getMod Reads a mod's entry.
 * @property {(entry: object) => Promise<void>} putMod Writes a mod's entry.
 * @property {(key: string) => Promise<void>} removeMod Deletes a mod's entry and its uploaded files.
 * @property {() => Promise<object[]>} allMods Reads every mod's entry.
 * @property {(key: string, bytes: Uint8Array) => Promise<void>} putModFile Writes an uploaded mod's zip.
 * @property {(key: string) => Promise<Uint8Array | undefined>} getModFile Reads an uploaded mod's zip.
 */

/**
 * The catalog of mods, over a store.
 */
export class ModCatalog {
  /**
   * Creates the catalog.
   *
   * @param {ModStore} store Where the mods are kept.
   * @param {{clock?: () => number, limits?: typeof MOD_LIMITS, admins?: string[], fetch?: typeof fetch}} [options] The clock, limits and fetch, which tests change, and the player ids of the relay's admins.
   */
  constructor(store, { clock = Date.now, limits = MOD_LIMITS, admins = [], fetch: fetcher = (...args) => fetch(...args) } = {}) {
    this.store = store;
    this.clock = clock;
    this.limits = limits;
    this.admins = new Set(admins);
    this.fetch = fetcher;
  }

  /**
   * Lists the mods, with how each was checked for an admin.
   *
   * @param {unknown} [key] The asking player's key.
   * @returns {Promise<{status: number, body: object}>} The mods, and whether the player is an admin.
   */
  async list(key) {
    const admin = await this.isAdmin(key);
    const mods = (await this.store.allMods()).sort((a, b) => a.name.localeCompare(b.name)).map((entry) => (admin ? adminView(entry) : publicView(entry)));
    return { status: 200, body: { mods, admin } };
  }

  /**
   * Adds a mod by its download link, or changes a mod's link, and checks it at once.
   *
   * @param {unknown} key The asking player's key.
   * @param {unknown} name The mod's name, as worlds write it.
   * @param {unknown} link A link to the mod's script on the admins' GitHub, the same for every version.
   * @returns {Promise<{status: number, body: object}>} The mod as checked, or why it was refused.
   */
  async setLink(key, name, link) {
    if (!(await this.isAdmin(key))) {
      return forbidden();
    }

    const cleaned = cleanText(name, this.limits.maxNameLength);

    if (!cleaned || modKey(cleaned).length === 0) {
      return badRequest("the mod needs a name");
    }

    if (typeof link !== "string" || !link.startsWith(LINK_START)) {
      return badRequest(`the link must start with ${LINK_START}`);
    }

    const refusal = await this.roomFor(modKey(cleaned));

    if (refusal) {
      return refusal;
    }

    const existing = await this.store.getMod(modKey(cleaned));
    const entry = existing?.kind === "link" ? { ...existing, name: cleaned, link } : newEntry(modKey(cleaned), cleaned, "link");
    entry.link = link;

    if (existing && existing.kind !== "link") {
      await this.store.removeMod(existing.key);
    }

    await this.checkLink(entry);
    await this.store.putMod(entry);
    return { status: 200, body: { mod: adminView(entry) } };
  }

  /**
   * Keeps a mod of several files that an admin uploads as a zip, with each file's hash.
   *
   * @param {unknown} key The asking player's key.
   * @param {unknown} name The mod's name, as worlds write it.
   * @param {unknown} version The version the admin gives it.
   * @param {Uint8Array | null} body The manifest, one "path\thash" line per file and an empty line, then the zip; null when it was too large.
   * @returns {Promise<{status: number, body: object}>} The mod, or why it was refused.
   */
  async upload(key, name, version, body) {
    if (!(await this.isAdmin(key))) {
      return forbidden();
    }

    const cleaned = cleanText(name, this.limits.maxNameLength);
    const label = cleanText(version, this.limits.maxVersionLength);

    if (!cleaned || modKey(cleaned).length === 0 || !label) {
      return badRequest("the mod needs a name and a version");
    }

    if (!body) {
      return { status: 413, body: { error: `an upload may be at most ${this.limits.maxUploadBytes} bytes` } };
    }

    const parsed = splitUpload(body, this.limits);

    if (typeof parsed === "string") {
      return badRequest(parsed);
    }

    const refusal = await this.roomFor(modKey(cleaned));

    if (refusal) {
      return refusal;
    }

    const existing = await this.store.getMod(modKey(cleaned));
    const entry = existing?.kind === "upload" ? { ...existing, name: cleaned } : newEntry(modKey(cleaned), cleaned, "upload");

    if (existing && existing.kind !== "upload") {
      await this.store.removeMod(existing.key);
    }

    remember(entry, label, parsed.files, this.clock(), this.limits);
    entry.size = parsed.zip.length;
    entry.checked = this.clock();
    entry.error = "";
    await this.store.putModFile(entry.key, parsed.zip);
    await this.store.putMod(entry);
    return { status: 200, body: { mod: adminView(entry) } };
  }

  /**
   * Removes a mod from the catalog.
   *
   * @param {unknown} key The asking player's key.
   * @param {string} modKeyOf The mod's key.
   * @returns {Promise<{status: number, body: object}>} The answer.
   */
  async remove(key, modKeyOf) {
    if (!(await this.isAdmin(key))) {
      return forbidden();
    }

    if (!(await this.store.getMod(modKeyOf))) {
      return notFound();
    }

    await this.store.removeMod(modKeyOf);
    return { status: 200, body: { deleted: modKeyOf } };
  }

  /**
   * Checks every link mod now, as an admin asks.
   *
   * @param {unknown} key The asking player's key.
   * @returns {Promise<{status: number, body: object}>} The mods as checked.
   */
  async check(key) {
    if (!(await this.isAdmin(key))) {
      return forbidden();
    }

    await this.checkAll();
    return this.list(key);
  }

  /**
   * Checks every link mod for a new release, as the schedule does.
   *
   * @returns {Promise<number>} How many mods have a new version.
   */
  async checkAll() {
    let changed = 0;

    for (const entry of await this.store.allMods()) {
      if (entry.kind !== "link") {
        continue;
      }

      const version = entry.version;
      const files = JSON.stringify(entry.files);
      await this.checkLink(entry);
      await this.store.putMod(entry);

      if (entry.version !== version || JSON.stringify(entry.files) !== files) {
        changed += 1;
      }
    }

    return changed;
  }

  /**
   * Hands out an uploaded mod's zip.
   *
   * @param {string} modKeyOf The mod's key.
   * @returns {Promise<{status: number, body: object, bytes?: Uint8Array}>} The zip, or why there is none.
   */
  async file(modKeyOf) {
    const entry = await this.store.getMod(modKeyOf);
    const bytes = entry?.kind === "upload" ? await this.store.getModFile(entry.key) : undefined;
    return bytes ? { status: 200, body: {}, bytes } : notFound();
  }

  /**
   * Reads a link mod's current release and notes a new version, keeping the last good one when
   * the release cannot be read.
   *
   * @param {object} entry The mod, changed in place.
   */
  async checkLink(entry) {
    entry.checked = this.clock();

    try {
      const release = await readRelease(entry.link, this.fetch, this.limits);
      const archive = isZip(release.file);
      const files = archive ? await zipHashes(release.bytes, this.limits) : { [release.file]: await hashModFile(release.file, release.bytes) };
      entry.fileUrl = release.url;
      entry.archive = archive;
      entry.size = release.bytes.length;
      entry.error = "";
      remember(entry, release.version, files, this.clock(), this.limits);
    } catch (error) {
      entry.error = String(error?.message ?? error).slice(0, 200);
    }
  }

  /**
   * Tells whether the catalog may take another mod.
   *
   * @param {string} key The new mod's key.
   * @returns {Promise<{status: number, body: object} | null>} Why not, or null.
   */
  async roomFor(key) {
    const mods = await this.store.allMods();
    return mods.length >= this.limits.maxMods && !mods.some((entry) => entry.key === key) ? { status: 503, body: { error: "the catalog is full" } } : null;
  }

  /**
   * Tells whether a key is one of the relay's admins'.
   *
   * @param {unknown} key The player's key.
   * @returns {Promise<boolean>} Whether it is.
   */
  async isAdmin(key) {
    return typeof key === "string" && PLAYER_KEY.test(key) && this.admins.has(await playerIdOf(key));
  }
}

/**
 * Reads a link's release file: the link must lead to a release file on the admins' GitHub, whose
 * tag is the version, and that file may only come from GitHub's file hosts.
 *
 * @param {string} link The link, such as .../releases/latest/download/Mod.rb or .../Mod.zip.
 * @param {typeof fetch} fetcher Fetches an address.
 * @param {typeof MOD_LIMITS} limits The limits.
 * @returns {Promise<{url: string, file: string, version: string, bytes: Uint8Array}>} The release file's address, its name, the version and the file.
 */
export async function readRelease(link, fetcher, limits = MOD_LIMITS) {
  let url = link;

  if (!RELEASE_FILE.test(url)) {
    const answer = await fetcher(url, { redirect: "manual" });
    const location = answer.headers.get("Location");

    if (answer.status < 300 || answer.status >= 400 || !location) {
      throw new Error(`the link answered ${answer.status} instead of leading to a release`);
    }

    url = new URL(location, link).href;
  }

  const match = RELEASE_FILE.exec(url);

  if (!match) {
    throw new Error("the link does not lead to a script or zip of a release on GitHub");
  }

  const file = decodeURIComponent(match[2]);
  const bytes = await download(url, fetcher, limits, isZip(file) ? limits.maxUploadBytes : limits.maxLinkBytes);
  return { url, file, version: decodeURIComponent(match[1]).replace(/^v/i, ""), bytes };
}

/**
 * Downloads a release file, following only redirects to GitHub's file hosts.
 *
 * @param {string} url The release file's address.
 * @param {typeof fetch} fetcher Fetches an address.
 * @param {typeof MOD_LIMITS} limits The limits.
 * @param {number} maxBytes The most bytes the file may have.
 * @returns {Promise<Uint8Array>} The file.
 */
async function download(url, fetcher, limits, maxBytes) {
  let address = url;

  for (let hop = 0; hop <= limits.maxRedirects; hop += 1) {
    const answer = await fetcher(address, { redirect: "manual" });

    if (answer.status >= 300 && answer.status < 400) {
      const next = new URL(answer.headers.get("Location") ?? "", address);

      if (next.protocol !== "https:" || !FILE_HOSTS.includes(next.hostname)) {
        throw new Error(`the release file was sent on to ${next.hostname}, which is no GitHub file host`);
      }

      address = next.href;
      continue;
    }

    if (answer.status !== 200) {
      throw new Error(`the release file answered ${answer.status}`);
    }

    if (Number(answer.headers.get("Content-Length") ?? 0) > maxBytes) {
      throw new Error(`the release file is larger than ${maxBytes} bytes`);
    }

    const bytes = new Uint8Array(await answer.arrayBuffer());

    if (bytes.length === 0 || bytes.length > maxBytes) {
      throw new Error(`the release file must be 1 to ${maxBytes} bytes`);
    }

    return bytes;
  }

  throw new Error("the release file was sent on too often");
}

/**
 * Tells a zip from a script by its name.
 *
 * @param {string} file The file's name.
 * @returns {boolean} Whether it is a zip.
 */
function isZip(file) {
  return file.toLowerCase().endsWith(".zip");
}

/**
 * Hashes every file of a zip laid out as in the game's Patch folder.
 *
 * Only plain and deflated files are read, which every zip tool writes; the sizes the zip claims are
 * checked against the limits before anything is unpacked, and again after.
 *
 * @param {Uint8Array} bytes The zip.
 * @param {typeof MOD_LIMITS} limits The limits.
 * @returns {Promise<Record<string, string>>} Each file's hash by its path inside Patch.
 */
export async function zipHashes(bytes, limits = MOD_LIMITS) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const end = findEndOfDirectory(view);
  const count = view.getUint16(end + 10, true);
  let at = view.getUint32(end + 16, true);
  let unpacked = 0;
  const files = {};

  for (let index = 0; index < count; index += 1) {
    if (at + 46 > bytes.length || view.getUint32(at, true) !== 0x02014b50) {
      throw new Error("the zip's list of files is damaged");
    }

    const method = view.getUint16(at + 10, true);
    const packedSize = view.getUint32(at + 20, true);
    const size = view.getUint32(at + 24, true);
    const nameLength = view.getUint16(at + 28, true);
    const skip = nameLength + view.getUint16(at + 30, true) + view.getUint16(at + 32, true);
    const local = view.getUint32(at + 42, true);
    // Some zip tools of Windows write backslashes.
    const name = new TextDecoder().decode(bytes.subarray(at + 46, at + 46 + nameLength)).replace(/\\/g, "/");
    at += 46 + skip;

    if (name.endsWith("/")) {
      continue;
    }

    if (name.length > limits.maxPathLength || !PATCH_PATH.test(name)) {
      throw new Error(`the zip holds ${name.slice(0, 80)}, which is no path inside Patch`);
    }

    unpacked += size;

    if (Object.keys(files).length >= limits.maxFiles || unpacked > limits.maxUnpackedBytes) {
      throw new Error(`the zip may hold at most ${limits.maxFiles} files of ${limits.maxUnpackedBytes} bytes in all`);
    }

    const data = await unpack(bytes, view, local, method, packedSize, size, name);
    files[name] = await hashModFile(name, data);
  }

  if (Object.keys(files).length === 0) {
    throw new Error("the zip holds no files");
  }

  return files;
}

/**
 * Finds where a zip's end record starts.
 *
 * @param {DataView} view The zip.
 * @returns {number} The end record's offset.
 */
function findEndOfDirectory(view) {
  // The end record is 22 bytes, followed by a comment of at most 65535 bytes.
  for (let at = view.byteLength - 22; at >= 0 && at >= view.byteLength - 22 - 65535; at -= 1) {
    if (view.getUint32(at, true) === 0x06054b50) {
      return at;
    }
  }

  throw new Error("the release file is no zip");
}

/**
 * Unpacks one file of a zip.
 *
 * @param {Uint8Array} bytes The zip.
 * @param {DataView} view The zip.
 * @param {number} local Where the file's own header starts.
 * @param {number} method 0 for a plain file, 8 for a deflated one.
 * @param {number} packedSize Its size in the zip.
 * @param {number} size Its size unpacked.
 * @param {string} name Its path, for the error.
 * @returns {Promise<Uint8Array>} The file.
 */
async function unpack(bytes, view, local, method, packedSize, size, name) {
  if (local + 30 > bytes.length || view.getUint32(local, true) !== 0x04034b50) {
    throw new Error(`the zip's entry ${name.slice(0, 80)} is damaged`);
  }

  const start = local + 30 + view.getUint16(local + 26, true) + view.getUint16(local + 28, true);
  const packed = bytes.subarray(start, start + packedSize);

  if (packed.length !== packedSize) {
    throw new Error(`the zip's entry ${name.slice(0, 80)} is cut short`);
  }

  let data;

  if (method === 0) {
    data = packed;
  } else if (method === 8) {
    const stream = new Blob([packed]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
    data = new Uint8Array(await new Response(stream).arrayBuffer());
  } else {
    throw new Error(`the zip packs ${name.slice(0, 80)} in a way the relay does not read`);
  }

  if (data.length !== size) {
    throw new Error(`the zip's entry ${name.slice(0, 80)} is not the size the zip says`);
  }

  return data;
}

/**
 * Splits an upload into its manifest and its zip.
 *
 * @param {Uint8Array} body The upload: "path\thash" lines, an empty line, then the zip.
 * @param {typeof MOD_LIMITS} limits The limits.
 * @returns {{files: Record<string, string>, zip: Uint8Array} | string} The files' hashes by path and the zip, or what is wrong.
 */
export function splitUpload(body, limits = MOD_LIMITS) {
  const end = findBlankLine(body);

  if (end < 0) {
    return "the upload needs its file list, an empty line, then the zip";
  }

  const files = {};
  const lines = new TextDecoder().decode(body.subarray(0, end)).split("\n").filter((line) => line.length > 0);

  for (const line of lines) {
    const [path, hash] = line.split("\t");

    if (!path || path.length > limits.maxPathLength || !PATCH_PATH.test(path) || !HASH.test(hash ?? "")) {
      return `the file list has a line that is no path inside Patch and a hash: ${line.slice(0, 80)}`;
    }

    files[path] = hash;
  }

  const count = Object.keys(files).length;

  if (count === 0 || count > limits.maxFiles) {
    return `the upload must list 1 to ${limits.maxFiles} files`;
  }

  const zip = body.subarray(end + 2);
  return zip.length > 0 ? { files, zip: Uint8Array.from(zip) } : "the upload has no zip";
}

/**
 * Finds the empty line that ends an upload's file list.
 *
 * @param {Uint8Array} body The upload.
 * @returns {number} Where the empty line starts, -1 when there is none.
 */
function findBlankLine(body) {
  const limit = Math.min(body.length - 1, 64 * 1024);

  for (let index = 0; index < limit; index += 1) {
    if (body[index] === 10 && body[index + 1] === 10) {
      return index;
    }
  }

  return -1;
}

/**
 * Notes a mod's current files, as a new version when they changed.
 *
 * @param {object} entry The mod, changed in place.
 * @param {string} version The version.
 * @param {Record<string, string>} files The files' hashes by path.
 * @param {number} now The time.
 * @param {typeof MOD_LIMITS} limits The limits.
 */
function remember(entry, version, files, now, limits) {
  const same = JSON.stringify(entry.files) === JSON.stringify(files) && entry.version === version;

  entry.version = version;
  entry.files = files;

  if (!same) {
    entry.versions = [{ version, files, seen: now }, ...(entry.versions ?? []).filter((old) => JSON.stringify(old.files) !== JSON.stringify(files))].slice(0, limits.maxVersions);
  }
}

/**
 * Makes a mod's entry before its first check.
 *
 * @param {string} key The mod's key.
 * @param {string} name The mod's name.
 * @param {"link" | "upload"} kind How the mod reaches the relay.
 * @returns {object} The entry.
 */
function newEntry(key, name, kind) {
  return { key, name, kind, link: "", fileUrl: "", version: "", files: {}, versions: [], size: 0, checked: 0, error: "" };
}

/**
 * Makes the view of a mod every game may see.
 *
 * @param {object} entry The mod.
 * @returns {object} The view.
 */
export function publicView(entry) {
  return {
    key: entry.key,
    name: entry.name,
    kind: entry.kind,
    version: entry.version,
    files: entry.files,
    versions: (entry.versions ?? []).map(({ version, files }) => ({ version, files })),
    fileUrl: entry.kind === "link" ? entry.fileUrl : "",
    archive: entry.kind === "link" && entry.archive === true,
  };
}

/**
 * Makes the view of a mod an admin sees: how and when it was checked too.
 *
 * @param {object} entry The mod.
 * @returns {object} The view.
 */
function adminView(entry) {
  return { ...publicView(entry), link: entry.link, size: entry.size, checked: entry.checked, error: entry.error };
}

/**
 * Tidies a name or version: on one line, without control characters, trimmed and not too long.
 *
 * @param {unknown} text The text.
 * @param {number} maxLength The most characters kept.
 * @returns {string} The text, empty when there is none.
 */
function cleanText(text, maxLength) {
  return typeof text === "string" ? [...text.replace(BREAKERS, "").trim()].slice(0, maxLength).join("") : "";
}

/**
 * Answers a request to the catalog's routes.
 *
 * @param {ModCatalog} catalog The catalog.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address.
 * @param {() => Promise<string>} readBody Reads the request's body as text.
 * @param {(limit: number) => Promise<Uint8Array | null>} readBytes Reads the request's body as bytes, null when it is longer than the limit.
 * @returns {Promise<{status: number, body: object, bytes?: Uint8Array}>} The answer, sent as the bytes when there are any.
 */
export async function handleModRequest(catalog, method, url, readBody, readBytes) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);

  if (parts[0] !== "v1" || parts[1] !== "mods") {
    return notFound();
  }

  if (parts.length === 2 && method === "GET") {
    return catalog.list(url.searchParams.get("player"));
  }

  if (parts.length === 2 && method === "POST") {
    const body = await readJson(readBody);
    return catalog.setLink(body?.player, body?.name, body?.link);
  }

  if (parts.length === 3 && parts[2] === "check" && method === "POST") {
    const body = await readJson(readBody);
    return catalog.check(body?.player);
  }

  if (parts.length === 4 && parts[3] === "delete" && method === "POST") {
    const body = await readJson(readBody);
    return catalog.remove(body?.player, parts[2]);
  }

  if (parts.length === 4 && parts[3] === "upload" && method === "POST") {
    const params = url.searchParams;
    return catalog.upload(params.get("player"), params.get("name"), params.get("version"), await readBytes(catalog.limits.maxUploadBytes));
  }

  if (parts.length === 4 && parts[3] === "file" && method === "GET") {
    return catalog.file(parts[2]);
  }

  return { status: 405, body: { error: "not a mod catalog route" } };
}

/**
 * Reads a JSON body, small ones only.
 *
 * @param {() => Promise<string>} readBody Reads the request's body.
 * @returns {Promise<any>} The parsed body, or null when it is no JSON or too large.
 */
async function readJson(readBody) {
  try {
    const text = await readBody();
    return text.length <= 8192 ? JSON.parse(text) : null;
  } catch {
    return null;
  }
}

/**
 * The answer for a mod that does not exist.
 *
 * @returns {{status: number, body: object}} The answer.
 */
function notFound() {
  return { status: 404, body: { error: "there is no such mod" } };
}

/**
 * The answer for a request only the relay's admins may make.
 *
 * @returns {{status: number, body: object}} The answer.
 */
function forbidden() {
  return { status: 403, body: { error: "only the relay's admins may change the mod catalog" } };
}

/**
 * The answer for a request that is not as it should be.
 *
 * @param {string} reason Why.
 * @returns {{status: number, body: object}} The answer.
 */
function badRequest(reason) {
  return { status: 400, body: { error: reason } };
}
