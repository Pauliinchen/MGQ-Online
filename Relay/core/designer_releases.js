//----------------------------------------------------------------
//  designer_releases.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

// The newest Raid Designer release, for the designers the relay lists: the relay reads the private
// designer repository's latest release with a read-only token that never leaves the server, checks
// the signed manifest and the exe against it, keeps the exe in DESIGN_DATA_DIR/releases and hands
// both out. The designer checks everything again; this check only keeps the cache clean. Node only,
// since it keeps files.

import { createHash, createPublicKey, verify } from "node:crypto";
import { once } from "node:events";
import { createReadStream, createWriteStream } from "node:fs";
import { mkdir, readFile, readdir, rename, rm, stat, writeFile } from "node:fs/promises";
import { join } from "node:path";

/**
 * The repository whose releases the relay serves, unless DESIGNER_REPO names another.
 */
export const DESIGNER_REPO = "Pauliinchen/MGQ-Online-Raid-Designer";

/**
 * The product a designer release's manifest names.
 */
export const DESIGNER_PRODUCT = "MGQ Online Raid Designer";

/**
 * The runtime whose file in the manifest is the desktop exe the relay serves.
 */
export const DESIGNER_RID = "win-x64";

/**
 * The limits and timings of the designer releases.
 */
export const DESIGNER_RELEASE_LIMITS = Object.freeze({
  checkEveryMs: 30 * 60 * 1000,
  maxManifestBytes: 64 * 1024,
  maxSignatureBytes: 1024,
  maxExeBytes: 1024 * 1024 * 1024,
  // How long a call to GitHub's API may take, and the download of the exe.
  apiTimeoutMs: 60 * 1000,
  exeTimeoutMs: 15 * 60 * 1000,
  // How long before the token's expiry the relay warns, and how often.
  warnBeforeExpiryMs: 30 * 24 * 60 * 60 * 1000,
  warnEveryMs: 24 * 60 * 60 * 1000,
});

/**
 * The folder under DESIGN_DATA_DIR the releases are kept in.
 */
const RELEASES_FOLDER = "releases";

/**
 * The file in RELEASES_FOLDER that names the release the relay serves.
 */
const CURRENT_FILE = "current.json";

/**
 * A release version: three numbers and an optional pre-release suffix, as the release workflow
 * reads it from the tag.
 */
const RELEASE_VERSION = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/;

/**
 * A SHA-256 as the manifest writes it.
 */
const SHA256 = /^[0-9a-f]{64}$/;

/**
 * The GitHub API's version the requests ask for.
 */
const GITHUB_API_VERSION = "2022-11-28";

/**
 * Names the files of a designer release, as the release workflow uploads them.
 *
 * @param {string} version The version, like 1.3.0.
 * @returns {{exe: string, manifest: string, signature: string}} The desktop exe's, the manifest's and the manifest signature's file names.
 */
export function releaseFileNames(version) {
  const manifest = `RaidDesigner-${version}.manifest.json`;
  return { exe: `RaidDesigner-${version}-${DESIGNER_RID}.exe`, manifest, signature: `${manifest}.sig` };
}

/**
 * Reads the designer release settings from the environment.
 *
 * @param {Record<string, string | undefined>} env The environment: DESIGNER_REPO, DESIGNER_GITHUB_TOKEN, DESIGNER_RELEASE_PUBKEY (a PEM, its line breaks also written as \n), DESIGN_DATA_DIR and DESIGNER_GITHUB_TOKEN_EXPIRES (a date like 2027-10-01).
 * @returns {{repo: string, token: string, publicKey: string, dataDir: string, tokenExpires: number | null} | null} The settings, the expiry in milliseconds; null while the token, the key or the folder is missing, which leaves the releases off.
 */
export function designerReleaseSettingsOf(env) {
  const token = env.DESIGNER_GITHUB_TOKEN?.trim();
  const publicKey = env.DESIGNER_RELEASE_PUBKEY?.replace(/\\n/g, "\n").trim();
  const dataDir = env.DESIGN_DATA_DIR?.trim();

  if (!token || !publicKey || !dataDir) {
    return null;
  }

  const expires = Date.parse(env.DESIGNER_GITHUB_TOKEN_EXPIRES?.trim() ?? "");
  return { repo: env.DESIGNER_REPO?.trim() || DESIGNER_REPO, token, publicKey, dataDir, tokenExpires: Number.isNaN(expires) ? null : expires };
}

/**
 * Checks a manifest's signature and reads the desktop exe's entry from it.
 *
 * @param {Uint8Array} manifest The manifest's exact bytes.
 * @param {Uint8Array} signature Its DER ECDSA P-256 SHA-256 signature.
 * @param {import("node:crypto").KeyObject} publicKey The release key.
 * @param {string} version The version the release's tag names.
 * @returns {{notes: string, exe: {name: string, size: number, sha256: string}}} The release notes and the exe's name, size and SHA-256.
 * @throws {Error} When the signature does not verify or the manifest is not one of this version.
 */
export function readSignedManifest(manifest, signature, publicKey, version) {
  let good = false;

  try {
    good = verify("sha256", manifest, { key: publicKey, dsaEncoding: "der" }, signature);
  } catch {
    // A signature that is no DER sequence is as bad as a wrong one.
  }

  if (!good) {
    throw new Error("the manifest's signature does not verify");
  }

  const read = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(manifest));
  const exe = Array.isArray(read?.files) ? read.files.find((file) => file?.rid === DESIGNER_RID) : undefined;

  if (read?.product !== DESIGNER_PRODUCT || read.version !== version) {
    throw new Error(`the manifest names ${read?.product} ${read?.version}, not ${DESIGNER_PRODUCT} ${version}`);
  }

  if (exe?.name !== releaseFileNames(version).exe || !Number.isSafeInteger(exe.size) || exe.size <= 0 || typeof exe.sha256 !== "string" || !SHA256.test(exe.sha256)) {
    throw new Error(`the manifest names no ${DESIGNER_RID} exe of this release`);
  }

  return { notes: typeof read.notes === "string" ? read.notes : "", exe: { name: exe.name, size: exe.size, sha256: exe.sha256 } };
}

/**
 * Reads which bytes of a file a request's Range header asks for; a header that is no single byte
 * range asks for the whole file.
 *
 * @param {string | null | undefined} header The Range header.
 * @param {number} size The file's length.
 * @returns {{start: number, end: number, partial: boolean} | null} The first and last byte and whether that is part of the file; null when the range lies past the end.
 */
export function byteRangeOf(header, size) {
  const whole = { start: 0, end: size - 1, partial: false };
  const match = typeof header === "string" ? /^\s*bytes\s*=\s*(\d*)\s*-\s*(\d*)\s*$/i.exec(header) : null;

  if (!match || (match[1] === "" && match[2] === "")) {
    return whole;
  }

  if (match[1] === "") {
    const suffix = Number(match[2]);
    return suffix === 0 ? null : { start: Math.max(0, size - suffix), end: size - 1, partial: true };
  }

  const start = Number(match[1]);
  const end = match[2] === "" ? size - 1 : Math.min(Number(match[2]), size - 1);

  if (match[2] !== "" && Number(match[2]) < start) {
    return whole;
  }

  return start >= size ? null : { start, end, partial: true };
}

/**
 * Hashes a file.
 *
 * @param {string} path The file.
 * @returns {Promise<{sha256: string, size: number}>} Its SHA-256 and length.
 */
async function hashFile(path) {
  const hash = createHash("sha256");
  let size = 0;

  for await (const chunk of createReadStream(path)) {
    hash.update(chunk);
    size += chunk.length;
  }

  return { sha256: hash.digest("hex"), size };
}

/**
 * Reads a response's body up to a limit.
 *
 * @param {Response} response The response.
 * @param {number} limit The most bytes taken.
 * @param {string} what What the body is, for the error.
 * @returns {Promise<Uint8Array>} The bytes.
 * @throws {Error} When the body is longer.
 */
async function readLimited(response, limit, what) {
  const chunks = [];
  let size = 0;

  for await (const chunk of response.body ?? []) {
    size += chunk.length;

    if (size > limit) {
      throw new Error(`the ${what} is longer than ${limit} bytes`);
    }

    chunks.push(chunk);
  }

  return Buffer.concat(chunks);
}

/**
 * The newest designer release the relay serves, read from GitHub and kept in DESIGN_DATA_DIR.
 */
export class DesignerReleases {
  /**
   * Creates the releases, holding none until load or check finds one.
   *
   * @param {{repo: string, token: string, publicKey: string, dataDir: string, tokenExpires?: number | null}} settings The settings, see designerReleaseSettingsOf.
   * @param {{fetcher?: typeof fetch, clock?: () => number, log?: {info: (line: string) => void, error: (line: string) => void}, limits?: typeof DESIGNER_RELEASE_LIMITS, api?: string}} [options] Fetches an address and the clock, which tests change; where warnings go; the limits; GitHub's API address.
   * @throws {Error} When the public key is no key.
   */
  constructor(settings, { fetcher = fetch, clock = Date.now, log = console, limits = DESIGNER_RELEASE_LIMITS, api = "https://api.github.com" } = {}) {
    this.repo = settings.repo;
    this.token = settings.token;
    this.publicKey = createPublicKey(settings.publicKey);
    this.folder = join(settings.dataDir, RELEASES_FOLDER);
    this.tokenExpires = settings.tokenExpires ?? null;
    this.fetcher = fetcher;
    this.clock = clock;
    this.log = log;
    this.limits = limits;
    this.api = api;
    /** @type {{version: string, notes: string, manifest: string, signature: string, sha256: string, size: number, name: string, manifestAsset: number} | null} */
    this.current = null;
    /** @type {string | null} */
    this.previousSha = null;
    /** @type {Promise<string | null> | null} */
    this.checking = null;
    this.warnedAt = null;
  }

  /**
   * Takes up the release kept from before a restart, once its manifest still verifies and its exe
   * is whole; anything else is left for the next check.
   *
   * @returns {Promise<string | null>} The version taken up, null for none.
   */
  async load() {
    let record;

    try {
      record = JSON.parse(await readFile(join(this.folder, CURRENT_FILE), "utf8"));
      const { exe } = readSignedManifest(Buffer.from(record.manifest, "base64"), Buffer.from(record.signature, "base64"), this.publicKey, record.version);
      const kept = await hashFile(this.exePath(exe.sha256));

      if (kept.sha256 !== exe.sha256 || kept.size !== exe.size || record.sha256 !== exe.sha256) {
        throw new Error("the kept exe differs from its manifest");
      }
    } catch (error) {
      if (error?.code !== "ENOENT") {
        this.log.error(`the kept designer release is not taken up: ${error.message}`);
      }

      return null;
    }

    this.current = record;
    return record.version;
  }

  /**
   * Reads the latest release from GitHub and, once it differs from the one served, checks it,
   * keeps it and serves it; one check at a time.
   *
   * @returns {Promise<string | null>} The version newly served, null when nothing changed.
   * @throws {Error} When GitHub fails or the release does not check out; the one served stays.
   */
  check() {
    this.checking ??= this.checkLatest().finally(() => {
      this.checking = null;
    });
    return this.checking;
  }

  /**
   * Does the work of check.
   *
   * @returns {Promise<string | null>} The version newly served, null when nothing changed.
   */
  async checkLatest() {
    this.warnOfExpiry();
    const answer = await this.github(`/repos/${this.repo}/releases/latest`, "application/vnd.github+json", this.limits.apiTimeoutMs);

    if (answer.status === 404) {
      return null;
    }

    const latest = JSON.parse(new TextDecoder().decode(await readLimited(answer, this.limits.maxManifestBytes * 16, "latest release")));
    const version = typeof latest?.tag_name === "string" ? latest.tag_name.replace(/^v/, "") : "";

    if (!RELEASE_VERSION.test(version)) {
      throw new Error(`the latest designer release's tag ${latest?.tag_name} names no version`);
    }

    const names = releaseFileNames(version);
    const assets = Object.fromEntries(Object.entries(names).map(([key, name]) => [key, (latest.assets ?? []).find((asset) => asset?.name === name)]));
    const missing = Object.entries(assets).filter(([, asset]) => !Number.isSafeInteger(asset?.id)).map(([key]) => names[key]);

    if (missing.length > 0) {
      throw new Error(`the latest designer release ${version} lacks ${missing.join(", ")}`);
    }

    if (this.current?.version === version && this.current.manifestAsset === assets.manifest.id) {
      return null;
    }

    const manifest = await this.download(assets.manifest.id, this.limits.maxManifestBytes, "manifest");
    const signature = await this.download(assets.signature.id, this.limits.maxSignatureBytes, "signature");
    const { notes, exe } = readSignedManifest(manifest, signature, this.publicKey, version);

    if (exe.size > this.limits.maxExeBytes || assets.exe.size !== exe.size) {
      throw new Error(`the exe of designer release ${version} is ${assets.exe.size} bytes, its manifest names ${exe.size}`);
    }

    await this.keepExe(assets.exe.id, exe);
    const record = { version, notes, manifest: manifest.toString("base64"), signature: signature.toString("base64"), sha256: exe.sha256, size: exe.size, name: exe.name, manifestAsset: assets.manifest.id };
    const earlier = this.current;
    await this.writeCurrent(record);
    this.previousSha = earlier && earlier.sha256 !== record.sha256 ? earlier.sha256 : this.previousSha;
    this.current = record;
    await this.prune();
    return earlier?.version === record.version && earlier.sha256 === record.sha256 ? null : version;
  }

  /**
   * Answers `GET release`.
   *
   * @param {string} minimum The lowest designer version the relay serves.
   * @returns {{status: number, body: object}} The release; `404 none` while none is served.
   */
  answer(minimum) {
    const current = this.current;

    if (!current) {
      return { status: 404, body: { code: "none" } };
    }

    return { status: 200, body: { version: current.version, minimum, notes: current.notes, manifest: current.manifest, signature: current.signature, size: current.size, sha256: current.sha256 } };
  }

  /**
   * Names the exe of the release served.
   *
   * @returns {{path: string, name: string, size: number, sha256: string} | null} The file, null while none is served.
   */
  file() {
    const current = this.current;
    return current ? { path: this.exePath(current.sha256), name: current.name, size: current.size, sha256: current.sha256 } : null;
  }

  /**
   * Serves a release as it is, for a release kept elsewhere or a test; load and check verify first.
   *
   * @param {{version: string, notes: string, manifest: string, signature: string, sha256: string, size: number, name: string, manifestAsset?: number}} record The release, manifest and signature in base64.
   */
  restore(record) {
    this.current = { manifestAsset: 0, ...record };
  }

  /**
   * Tells where the exe of a SHA-256 is kept.
   *
   * @param {string} sha256 The exe's SHA-256.
   * @returns {string} The path.
   */
  exePath(sha256) {
    return join(this.folder, `${sha256}.exe`);
  }

  /**
   * Calls GitHub's API with the token.
   *
   * @param {string} path The path after the API's address.
   * @param {string} accept The Accept header.
   * @param {number} timeoutMs How long it may take.
   * @returns {Promise<Response>} The answer, a 404 included.
   * @throws {Error} For any other answer than 200 or 404.
   */
  async github(path, accept, timeoutMs) {
    const answer = await this.fetcher(`${this.api}${path}`, {
      headers: { Accept: accept, Authorization: `Bearer ${this.token}`, "X-GitHub-Api-Version": GITHUB_API_VERSION, "User-Agent": "mgq-online-relay" },
      signal: AbortSignal.timeout(timeoutMs),
    });

    if (answer.status !== 200 && answer.status !== 404) {
      await answer.body?.cancel();
      throw new Error(`GitHub answered ${answer.status} to ${path}`);
    }

    return answer;
  }

  /**
   * Downloads a small release asset.
   *
   * @param {number} id The asset's id.
   * @param {number} limit The most bytes taken.
   * @param {string} what What the asset is, for the error.
   * @returns {Promise<Buffer>} The bytes.
   */
  async download(id, limit, what) {
    const answer = await this.github(`/repos/${this.repo}/releases/assets/${id}`, "application/octet-stream", this.limits.apiTimeoutMs);

    if (answer.status !== 200) {
      throw new Error(`the ${what} asset ${id} is gone`);
    }

    return Buffer.from(await readLimited(answer, limit, what));
  }

  /**
   * Keeps the exe of a release under its SHA-256, downloading it unless it is kept already.
   *
   * @param {number} id The exe asset's id.
   * @param {{size: number, sha256: string}} exe The exe's size and SHA-256 from the manifest.
   * @returns {Promise<void>} Completes once kept.
   * @throws {Error} When the download differs from the manifest.
   */
  async keepExe(id, exe) {
    const path = this.exePath(exe.sha256);

    if ((await stat(path).catch(() => null))?.size === exe.size) {
      return;
    }

    await mkdir(this.folder, { recursive: true });
    const part = `${path}.part`;
    const answer = await this.github(`/repos/${this.repo}/releases/assets/${id}`, "application/octet-stream", this.limits.exeTimeoutMs);

    try {
      if (answer.status !== 200) {
        throw new Error(`the exe asset ${id} is gone`);
      }

      const hash = createHash("sha256");
      const out = createWriteStream(part);
      let size = 0;

      try {
        for await (const chunk of answer.body ?? []) {
          size += chunk.length;

          if (size > exe.size) {
            throw new Error(`the exe is longer than its manifest's ${exe.size} bytes`);
          }

          hash.update(chunk);

          if (!out.write(chunk)) {
            await once(out, "drain");
          }
        }
      } finally {
        out.end();
        await once(out, "close");
      }

      const sha256 = hash.digest("hex");

      if (size !== exe.size || sha256 !== exe.sha256) {
        throw new Error(`the exe's SHA-256 ${sha256} (${size} bytes) differs from its manifest's ${exe.sha256} (${exe.size} bytes)`);
      }

      await rename(part, path);
    } finally {
      await rm(part, { force: true });
    }
  }

  /**
   * Writes which release is served, so a restart serves it at once.
   *
   * @param {object} record The release.
   * @returns {Promise<void>} Completes once written.
   */
  async writeCurrent(record) {
    const path = join(this.folder, CURRENT_FILE);
    await writeFile(`${path}.part`, JSON.stringify(record));
    await rename(`${path}.part`, path);
  }

  /**
   * Removes the exes of older releases but the one served before, which a download may still read.
   *
   * @returns {Promise<void>} Completes once removed.
   */
  async prune() {
    const keep = new Set([this.current?.sha256, this.previousSha].filter(Boolean).map((sha) => `${sha}.exe`));

    for (const name of await readdir(this.folder)) {
      if (name.endsWith(".exe") && !keep.has(name)) {
        await rm(join(this.folder, name), { force: true });
      }
    }
  }

  /**
   * Warns once a day from DESIGNER_RELEASE_LIMITS.warnBeforeExpiryMs before the token expires,
   * since the releases stop once it has.
   */
  warnOfExpiry() {
    const now = this.clock();

    if (this.tokenExpires === null || now < this.tokenExpires - this.limits.warnBeforeExpiryMs || (this.warnedAt !== null && now - this.warnedAt < this.limits.warnEveryMs)) {
      return;
    }

    this.warnedAt = now;
    this.log.error(`the designer release token DESIGNER_GITHUB_TOKEN expires on ${new Date(this.tokenExpires).toISOString().slice(0, 10)}; designer updates stop once it has`);
  }
}
