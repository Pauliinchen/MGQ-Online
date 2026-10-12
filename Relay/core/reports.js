//----------------------------------------------------------------
//  reports.js
//
//  Changelog:
//      Paulinchen  2026-10-12: Counted a report against the rate limits before unpacking it, so reports sent at once no longer pass together, and handled at most two at a time
//      Paulinchen  2026-10-11: Created
//
//----------------------------------------------------------------

// The bug reports players send from the game, the same on every server. The relay checks a report,
// commits its files as one folder of plain files to a private repository, report.md its index, and
// opens a public issue that links them, so only the developer can open the files while the
// player's title and text are public.
//
// A report's body is one line of JSON, then the base64 of each file with nothing between them. The
// text files arrive gzipped and are unpacked here, since GitHub keeps them readable only as text;
// the screenshot's base64 goes to GitHub as sent, since decoding it would only cost time a free
// Cloudflare plan does not grant.

import { playerIdOf } from "./directory.js";
import { badRequest, notFound, tooLarge } from "./http.js";
import { CONTROL_CHARACTERS, hexOf, isId } from "./ids.js";
import { VERSION } from "./relay.js";

/**
 * The limits a report keeps.
 */
export const REPORT_LIMITS = Object.freeze({
  maxBodyBytes: 15 * 1024 * 1024,
  maxHeaderLength: 16 * 1024,
  maxTitleLength: 100,
  maxTextLength: 4000,
  maxFacts: 12,
  maxLabelLength: 32,
  maxValueLength: 120,
  maxFiles: 32,
  maxNameLength: 120,
  maxScreenshotLength: 4 * 1024 * 1024,
  maxTextBytes: 8 * 1024 * 1024,
  maxTextBytesTotal: 24 * 1024 * 1024,
  commitTries: 3,
  githubTimeoutMs: 60 * 1000,
  maxPending: 2,
});

/**
 * The files with a role of their own: the report's index, which every report carries, and the
 * screenshot, the one binary file.
 */
export const REPORT_FILE = Object.freeze({ index: "report.md", screenshot: "screenshot.png" });

/**
 * How many reports a player or an address may send: at most `max` within `windowMs`.
 */
export const REPORT_RATES = Object.freeze([
  Object.freeze({ of: "player", max: 3, windowMs: 60 * 60 * 1000 }),
  Object.freeze({ of: "player", max: 10, windowMs: 24 * 60 * 60 * 1000 }),
  Object.freeze({ of: "address", max: 6, windowMs: 60 * 60 * 1000 }),
]);

/**
 * Where reports go unless the relay's settings name other repositories or another branch.
 */
export const REPORT_DEFAULTS = Object.freeze({
  issuesRepo: "Pauliinchen/MGQ-Online",
  filesRepo: "Pauliinchen/MGQ-Online-Bug-Reports",
  branch: "main",
});

/**
 * The codes a refusal names why with, which games tell their players apart.
 */
export const REPORT_REFUSAL = Object.freeze({ player: "player", rate: "rate", off: "off", github: "github", busy: "busy" });

/**
 * The label every issue of a report gets.
 */
export const REPORT_LABEL = "in-game report";

/**
 * The start of every issue title of a report.
 */
export const TITLE_PREFIX = "[In-game] ";

/**
 * The address of GitHub's API.
 */
export const GITHUB_API = "https://api.github.com";

/**
 * A mod or DLL version, such as 0.6.3 or 0.7.0-dev+1.
 */
const VERSION_TEXT = /^[0-9A-Za-z.+-]{1,32}$/;

/**
 * Base64 text with its padding at the end only.
 */
const BASE64 = /^[A-Za-z0-9+/]*={0,2}$/;

/**
 * One segment of a file's name: a letter or digit, then letters, digits, spaces and . _ ( ) + -.
 */
const NAME_SEGMENT = /^[A-Za-z0-9][A-Za-z0-9 ._()+-]*$/;

/**
 * The endings of a text file's name.
 */
const TEXT_NAME = /\.(?:md|log|txt)$/i;

/**
 * What unpack hands back for a gzip stream that does not unpack.
 */
const BROKEN = Symbol("broken");

/**
 * A line break, which titles, labels and values may not hold.
 */
const LINE_BREAK = /[\r\n]/;

/**
 * Control characters a report's text drops, all but its line breaks and tabs.
 */
const TEXT_CONTROL_CHARACTERS = /[\u0000-\u0008\u000b-\u001f\u007f]/g;

/**
 * The zero-width space put after every "@", so no name in a report mentions anyone on GitHub.
 */
const ZERO_WIDTH_SPACE = String.fromCharCode(0x200b);

/**
 * Reads where reports go from the relay's settings, the defaults for every one not set.
 *
 * Two tokens, so the one that writes contents reaches the private repository alone, never the
 * public one the mod's updater downloads from.
 *
 * @param {Record<string, string | undefined>} env The settings: GITHUB_ISSUES_TOKEN, GITHUB_BUG_FILES_TOKEN, REPORT_ISSUES_REPO,
 *   REPORT_FILES_REPO and REPORT_FILES_BRANCH.
 * @returns {{issuesToken: string | null, filesToken: string | null, issuesRepo: string, filesRepo: string, branch: string}} The token that opens issues and the one that commits files, each null when not
 *   set, and where issues and files go.
 */
export function reportSettingsOf(env) {
  const setting = (name) => (typeof env?.[name] === "string" && env[name].trim().length > 0 ? env[name].trim() : null);

  return {
    issuesToken: setting("GITHUB_ISSUES_TOKEN"),
    filesToken: setting("GITHUB_BUG_FILES_TOKEN"),
    issuesRepo: setting("REPORT_ISSUES_REPO") ?? REPORT_DEFAULTS.issuesRepo,
    filesRepo: setting("REPORT_FILES_REPO") ?? REPORT_DEFAULTS.filesRepo,
    branch: setting("REPORT_FILES_BRANCH") ?? REPORT_DEFAULTS.branch,
  };
}

/**
 * Counts what each player or address does within a sliding window, in memory.
 */
export class WindowLimiter {
  /**
   * Creates the limiter.
   *
   * @param {{max: number, windowMs: number}} limit At most `max` turns within `windowMs`.
   * @param {() => number} [clock] The clock, which tests change.
   * @param {number} [maxKeys] Most players or addresses remembered; the least recent ones are forgotten first.
   */
  constructor(limit, clock = Date.now, maxKeys = 10_000) {
    this.limit = limit;
    this.clock = clock;
    this.maxKeys = maxKeys;
    this.turns = new Map();
  }

  /**
   * Tells whether a player or address has a turn left.
   *
   * @param {string | null | undefined} key The player or address; without one nothing is limited.
   * @returns {boolean} Whether it may go on.
   */
  allows(key) {
    return !key || this.recent(key).length < this.limit.max;
  }

  /**
   * Takes one turn for a player or address.
   *
   * @param {string | null | undefined} key The player or address; without one nothing is counted.
   */
  take(key) {
    if (!key) {
      return;
    }

    const times = [...this.recent(key), this.clock()];

    // Taken out and put back, so the map keeps the least recent keys in front.
    this.turns.delete(key);
    this.turns.set(key, times);

    for (const oldest of this.turns.keys()) {
      if (this.turns.size <= this.maxKeys) {
        break;
      }

      this.turns.delete(oldest);
    }
  }

  /**
   * Gives back the last turn a player or address took, as for a report refused after its turn was
   * taken.
   *
   * @param {string | null | undefined} key The player or address; without one nothing is given back.
   */
  giveBack(key) {
    const times = key ? this.turns.get(key) : undefined;

    if (times?.length) {
      times.pop();
    }
  }

  /**
   * Lists the times a player or address took a turn within the window.
   *
   * @param {string} key The player or address.
   * @returns {number[]} The times, oldest first.
   */
  recent(key) {
    const since = this.clock() - this.limit.windowMs;
    return (this.turns.get(key) ?? []).filter((time) => time > since);
  }
}

/**
 * Reads a report's body: its JSON line and the base64 part of each file it lists, still packed.
 *
 * @param {string} body The body.
 * @param {typeof REPORT_LIMITS} [limits] The limits.
 * @returns {{report: {title: string, text: string, version: string, facts: [string, string][], files: {name: string, gzip: boolean, content: string}[]}} | {refusal: {status: number, body: object}}} The report, or why it is refused.
 */
export function parseReport(body, limits = REPORT_LIMITS) {
  const end = body.slice(0, limits.maxHeaderLength + 1).indexOf("\n");
  const line = end < 0 ? body : body.slice(0, end);

  if (line.length > limits.maxHeaderLength) {
    return refuse(`the header line may be at most ${limits.maxHeaderLength} characters`);
  }

  let header;

  try {
    header = JSON.parse(line);
  } catch {
    return refuse("the header line must be JSON");
  }

  if (!header || typeof header !== "object" || Array.isArray(header)) {
    return refuse("the header line must be a JSON object");
  }

  const title = singleLine(header.title);

  if (title === null || title.length < 1 || title.length > limits.maxTitleLength) {
    return refuse(`the title must be 1 to ${limits.maxTitleLength} characters on one line`);
  }

  const text = typeof header.text === "string" ? header.text.replace(/\r\n?/g, "\n").replace(TEXT_CONTROL_CHARACTERS, "").trim() : "";

  if (text.length < 1 || text.length > limits.maxTextLength) {
    return refuse(`the text must be 1 to ${limits.maxTextLength} characters`);
  }

  if (typeof header.version !== "string" || !VERSION_TEXT.test(header.version)) {
    return refuse("the version must be 1 to 32 letters, digits, dots, pluses or minuses");
  }

  const facts = factsOf(header.facts, limits);

  if (!facts) {
    return refuse(`the facts must be at most ${limits.maxFacts} pairs of a label of 1 to ${limits.maxLabelLength} and a value of up to ${limits.maxValueLength} characters, each on one line`);
  }

  return partsOf(header.files, end < 0 ? "" : body.slice(end + 1), limits, (parts) => ({ report: { title, text, version: header.version, facts, files: parts } }));
}

/**
 * Reads the facts of a report's header.
 *
 * @param {unknown} facts The facts as sent.
 * @param {typeof REPORT_LIMITS} limits The limits.
 * @returns {[string, string][] | null} The facts, or null when they break a rule.
 */
function factsOf(facts, limits) {
  if (!Array.isArray(facts) || facts.length > limits.maxFacts) {
    return null;
  }

  const read = [];

  for (const fact of facts) {
    if (!Array.isArray(fact) || fact.length !== 2) {
      return null;
    }

    const label = singleLine(fact[0]);
    const value = singleLine(fact[1]);

    if (label === null || value === null || label.length < 1 || label.length > limits.maxLabelLength || value.length > limits.maxValueLength) {
      return null;
    }

    read.push([label, value]);
  }

  return read;
}

/**
 * Cuts the base64 parts of a report's files out of the rest of its body, checking each against
 * what the header says of it.
 *
 * @param {unknown} listed The files as the header lists them.
 * @param {string} rest The body after the header line.
 * @param {typeof REPORT_LIMITS} limits The limits.
 * @param {(parts: {name: string, gzip: boolean, content: string}[]) => object} done Makes the result from the parts.
 * @returns {object} What `done` makes, or `{refusal}` for parts that break a rule.
 */
function partsOf(listed, rest, limits, done) {
  if (!Array.isArray(listed) || listed.length < 1 || listed.length > limits.maxFiles) {
    return refuse(`the files must be a list of 1 to ${limits.maxFiles}`);
  }

  const seen = new Set();
  let total = 0;

  for (const file of listed) {
    const refusal = fileRefusal(file, seen, limits);

    if (refusal) {
      return { refusal };
    }

    seen.add(file.name.toLowerCase());
    total += file.length;
  }

  if (!listed.some((file) => file.name === REPORT_FILE.index)) {
    return refuse(`every report carries ${REPORT_FILE.index}`);
  }

  if (total !== rest.length) {
    return refuse("the files' lengths must add up to the rest of the body");
  }

  const parts = [];
  let offset = 0;

  for (const { name, length, gzip } of listed) {
    const content = rest.slice(offset, offset + length);
    offset += length;

    if (!BASE64.test(content)) {
      return refuse(`${name} must be base64`);
    }

    parts.push({ name, gzip: gzip === true, content });
  }

  return done(parts);
}

/**
 * Checks one file the header lists: its name, kind, gzip flag and length.
 *
 * @param {any} file The file as listed.
 * @param {Set<string>} seen The names listed before it, in lower case.
 * @param {typeof REPORT_LIMITS} limits The limits.
 * @returns {{status: number, body: object} | null} Why it is refused, or null.
 */
function fileRefusal(file, seen, limits) {
  const name = file?.name;
  const segments = typeof name === "string" ? name.split("/") : [];

  if (segments.length < 1 || name.length > limits.maxNameLength || segments.length > 2 || !segments.every((segment) => NAME_SEGMENT.test(segment))) {
    return badRequest(`each file's name must be 1 to ${limits.maxNameLength} characters, a name or a folder and a name, of letters, digits, spaces and . _ ( ) + -, each starting with a letter or digit`);
  }

  if (seen.has(name.toLowerCase())) {
    return badRequest(`${name} is listed twice`);
  }

  if (file.gzip !== undefined && typeof file.gzip !== "boolean") {
    return badRequest(`${name}'s gzip must be true or false`);
  }

  if (name === REPORT_FILE.screenshot ? file.gzip === true : !TEXT_NAME.test(name)) {
    return badRequest(`${REPORT_FILE.screenshot} is the one binary file, never gzipped; every other file is text, ending in .md, .log or .txt`);
  }

  if (!Number.isInteger(file.length) || file.length < 4 || file.length % 4 !== 0) {
    return badRequest("each file's length must be a multiple of 4, at least 4");
  }

  return name === REPORT_FILE.screenshot && file.length > limits.maxScreenshotLength ? tooLarge(limits.maxScreenshotLength, `base64 characters for ${name}`) : null;
}

/**
 * Unpacks a report's text files: base64, then gzip where flagged, then UTF-8 with replacement
 * characters for broken bytes. Unpacking stops as soon as a file passes its limit, so a small
 * gzip stream cannot fill the memory.
 *
 * @param {{name: string, gzip: boolean, content: string}[]} files The files as parseReport read them.
 * @param {typeof REPORT_LIMITS} [limits] The limits.
 * @returns {Promise<{files: ({name: string, text: string} | {name: string, content: string})[]} | {refusal: {status: number, body: object}}>} Each text file with its text and the screenshot with its base64 as sent, or why the report is refused.
 */
export async function unpackFiles(files, limits = REPORT_LIMITS) {
  const unpacked = [];
  let total = 0;

  for (const { name, gzip, content } of files) {
    if (name === REPORT_FILE.screenshot) {
      unpacked.push({ name, content });
      continue;
    }

    const room = Math.min(limits.maxTextBytes, limits.maxTextBytesTotal - total);
    const bytes = gzip ? await gunzip(bytesOfBase64(content), room) : bytesOfBase64(content);

    if (bytes === BROKEN) {
      return refuse(`${name} does not unpack as gzip`);
    }

    if (bytes === null || bytes.length > room) {
      const error = room < limits.maxTextBytes ? `the text files may have at most ${limits.maxTextBytesTotal} bytes together` : `a text file may have at most ${limits.maxTextBytes} bytes`;
      return { refusal: { status: 413, body: { error: `${error}, unpacked` } } };
    }

    total += bytes.length;
    unpacked.push({ name, text: new TextDecoder().decode(bytes) });
  }

  return { files: unpacked };
}

/**
 * Decodes base64 into bytes.
 *
 * @param {string} text The base64, already checked.
 * @returns {Uint8Array} The bytes.
 */
function bytesOfBase64(text) {
  if (typeof Uint8Array.fromBase64 === "function") {
    return Uint8Array.fromBase64(text);
  }

  const binary = atob(text);
  const bytes = new Uint8Array(binary.length);

  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }

  return bytes;
}

/**
 * Unpacks a gzip stream, stopping once it passes a limit.
 *
 * @param {Uint8Array} bytes The gzip stream.
 * @param {number} limit The most bytes it may unpack to.
 * @returns {Promise<Uint8Array | null | typeof BROKEN>} The unpacked bytes, null past the limit, or BROKEN for a stream that does not unpack.
 */
async function gunzip(bytes, limit) {
  const reader = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip")).getReader();
  const chunks = [];
  let size = 0;

  try {
    for (let read = await reader.read(); !read.done; read = await reader.read()) {
      size += read.value.length;

      if (size > limit) {
        await reader.cancel().catch(() => {});
        return null;
      }

      chunks.push(read.value);
    }
  } catch {
    return BROKEN;
  }

  const unpacked = new Uint8Array(size);
  let offset = 0;

  for (const chunk of chunks) {
    unpacked.set(chunk, offset);
    offset += chunk.length;
  }

  return unpacked;
}

/**
 * Reads a text that must stay on one line, dropping other control characters and trimming it.
 *
 * @param {unknown} text The text.
 * @returns {string | null} The text, or null when it is no string or breaks a line.
 */
function singleLine(text) {
  return typeof text === "string" && !LINE_BREAK.test(text) ? text.replace(CONTROL_CHARACTERS, "").trim() : null;
}

/**
 * Makes a refusal of a report that breaks a rule.
 *
 * @param {string} reason Why.
 * @returns {{refusal: {status: number, body: object}}} The refusal.
 */
function refuse(reason) {
  return { refusal: badRequest(reason) };
}

/**
 * Keeps a text someone wrote from mentioning anyone on GitHub.
 *
 * @param {string} text The text.
 * @returns {string} The text with a zero-width space after every "@".
 */
export function neutralise(text) {
  return text.replaceAll("@", `@${ZERO_WIDTH_SPACE}`);
}

/**
 * Makes the address under which GitHub shows a report's file in the files repository.
 *
 * @param {{filesRepo: string, branch: string}} settings Where the files go.
 * @param {string} id The report.
 * @param {string} name The file's name, with its folder if it has one.
 * @returns {string} The address, each segment of the file's path encoded.
 */
export function fileLink(settings, id, name) {
  const path = ["reports", id, ...name.split("/")].map((segment) => encodeURIComponent(segment)).join("/");
  return `https://github.com/${settings.filesRepo}/blob/${settings.branch}/${path}`;
}

/**
 * Writes the body of a report's issue in Markdown: the player's text quoted, the facts as a table
 * and the links to the private report.md and screenshot.
 *
 * @param {{text: string, facts: [string, string][], files: {name: string}[]}} report The report.
 * @param {string} id The report's id.
 * @param {{filesRepo: string, branch: string}} settings Where the files went.
 * @returns {string} The Markdown.
 */
export function issueMarkdown(report, id, settings) {
  const cell = (text) => neutralise(text).replaceAll("|", "\\|");
  const sections = [neutralise(report.text).split("\n").map((line) => `> ${line}`).join("\n")];

  if (report.facts.length > 0) {
    sections.push(["| | |", "| --- | --- |", ...report.facts.map(([label, value]) => `| ${cell(label)} | ${cell(value)} |`)].join("\n"));
  }

  const linked = [REPORT_FILE.index, REPORT_FILE.screenshot].filter((name) => report.files.some((file) => file.name === name));

  if (linked.length > 0) {
    sections.push(`Full report (private): ${linked.map((name) => `[${name}](${fileLink(settings, id, name)})`).join(" · ")}`);
  }

  sections.push(`Report \`${id}\`, sent from the game.`);
  return sections.join("\n\n");
}

/**
 * Takes the bug reports players send and hands them to GitHub.
 */
export class ReportDesk {
  /**
   * Creates the desk.
   *
   * @param {{issuesToken: string | null, filesToken: string | null, issuesRepo: string, filesRepo: string, branch: string}} settings The GitHub tokens and where issues and files go, see reportSettingsOf.
   * @param {{clock?: () => number, fetch?: typeof fetch, random?: () => Uint8Array, limits?: typeof REPORT_LIMITS, rates?: typeof REPORT_RATES, log?: {info: (line: string) => void, error: (line: string) => void}}} [options] The clock, fetch, random bytes, limits, rate limits and log, which tests change.
   */
  constructor(settings, { clock = Date.now, fetch: fetcher = (...args) => fetch(...args), random = () => crypto.getRandomValues(new Uint8Array(4)), limits = REPORT_LIMITS, rates = REPORT_RATES, log = console } = {}) {
    this.settings = settings;
    this.clock = clock;
    this.fetch = fetcher;
    this.random = random;
    this.limits = limits;
    this.log = log;
    this.rates = rates.map((rate) => ({ of: rate.of, limiter: new WindowLimiter(rate, clock) }));
    this.pending = 0;
  }

  /**
   * Tells whether the relay takes reports, which it does once both GitHub tokens are set.
   *
   * @returns {boolean} Whether it does.
   */
  get enabled() {
    return [this.settings.issuesToken, this.settings.filesToken].every((token) => typeof token === "string" && token.length > 0);
  }

  /**
   * Takes a report: checks it, counts it against the rate limits, unpacks its text files and hands
   * it to GitHub, at most limits.maxPending at a time.
   *
   * @param {unknown} key The player's key.
   * @param {string | null} address The address the report came from, null when unknown.
   * @param {string | null} body The body, null when it was too large to read.
   * @returns {Promise<{status: number, body: object}>} The issue's number and address and the report's id, or why the report is refused.
   */
  async send(key, address, body) {
    if (!this.enabled) {
      return { status: 503, body: { error: "bug reports are off on this relay", code: REPORT_REFUSAL.off } };
    }

    if (!isId(key)) {
      return { status: 401, body: { error: "a player key is needed", code: REPORT_REFUSAL.player } };
    }

    if (body === null || body.length > this.limits.maxBodyBytes) {
      return tooLarge(this.limits.maxBodyBytes, "bytes");
    }

    const parsed = parseReport(body, this.limits);

    if (parsed.refusal) {
      return parsed.refusal;
    }

    const counted = { player: await playerIdOf(key), address };

    if (!this.allows(counted)) {
      return tooMany();
    }

    if (this.pending >= this.limits.maxPending) {
      return busy();
    }

    // Taken with no await since the questions, so reports sent at once cannot all pass them.
    this.take(counted);
    this.pending++;

    try {
      const unpacked = await unpackFiles(parsed.report.files, this.limits);

      if (unpacked.refusal) {
        this.giveBack(counted);
        return unpacked.refusal;
      }

      return await this.deliver({ ...parsed.report, files: unpacked.files });
    } finally {
      this.pending--;
    }
  }

  /**
   * Tells whether a player and an address have a report left under every rate limit.
   *
   * @param {{player: string, address: string | null}} counted The player's id and the address.
   * @returns {boolean} Whether they have.
   */
  allows(counted) {
    return this.rates.every(({ of, limiter }) => limiter.allows(counted[of]));
  }

  /**
   * Takes a turn for a player and an address under every rate limit.
   *
   * @param {{player: string, address: string | null}} counted The player's id and the address.
   */
  take(counted) {
    for (const { of, limiter } of this.rates) {
      limiter.take(counted[of]);
    }
  }

  /**
   * Gives back the turn take took for a player and an address.
   *
   * @param {{player: string, address: string | null}} counted The player's id and the address.
   */
  giveBack(counted) {
    for (const { of, limiter } of this.rates) {
      limiter.giveBack(counted[of]);
    }
  }

  /**
   * Commits a report's files to the files repository, then opens its issue.
   *
   * @param {{title: string, text: string, version: string, facts: [string, string][], files: ({name: string, text: string} | {name: string, content: string})[]}} report The report, its text files unpacked.
   * @returns {Promise<{status: number, body: object}>} The issue's number and address and the report's id, or 502 when GitHub refused or failed.
   */
  async deliver(report) {
    const id = this.newId();
    const { issuesRepo } = this.settings;

    try {
      const refusal = await this.commit(id, report);

      if (refusal) {
        return refusal;
      }

      const issue = { title: `${TITLE_PREFIX}${neutralise(report.title)}`, body: issueMarkdown(report, id, this.settings) };
      let answer = await this.github("POST", `/repos/${issuesRepo}/issues`, JSON.stringify({ ...issue, labels: [REPORT_LABEL] }), this.settings.issuesToken);

      if (answer.status === 422 && /label/i.test(await answer.clone().text())) {
        answer = await this.github("POST", `/repos/${issuesRepo}/issues`, JSON.stringify(issue), this.settings.issuesToken);
      }

      if (!answer.ok) {
        return this.failed(id, "opening the issue", answer);
      }

      const opened = await answer.json();
      const url = typeof opened.html_url === "string" ? opened.html_url : `https://github.com/${issuesRepo}/issues/${opened.number}`;
      this.log.info(`report ${id}: opened issue #${opened.number}`);
      return { status: 201, body: { issue: opened.number, url, id } };
    } catch (error) {
      this.log.error(`report ${id}: GitHub could not be reached or answered unreadably: ${error?.message ?? error}`);
      return githubFailed();
    }
  }

  /**
   * Commits a report's files as one commit on the files branch through GitHub's Git Data API:
   * the screenshot as a blob, the text files inline in a tree on top of the branch's head, then
   * the commit and the branch moved to it. A branch another report moved meanwhile is answered
   * with 422, and the commit is made again on the new head, up to `commitTries` in all.
   *
   * @param {string} id The report.
   * @param {{title: string, files: ({name: string, text: string} | {name: string, content: string})[]}} report The report, its text files unpacked.
   * @returns {Promise<{status: number, body: object} | null>} Null once committed, or the refusal after a step GitHub refused.
   */
  async commit(id, report) {
    const { filesRepo, branch, filesToken } = this.settings;
    const git = (method, path, body) => this.github(method, `/repos/${filesRepo}/git/${path}`, body, filesToken);
    const screenshot = report.files.find((file) => file.content !== undefined);
    let blob = null;

    for (let tries = 1; ; tries++) {
      const ref = await git("GET", `ref/heads/${branch}`);

      if (!ref.ok) {
        return this.failed(id, "reading the branch", ref);
      }

      const head = (await ref.json()).object.sha;
      const commit = await git("GET", `commits/${head}`);

      if (!commit.ok) {
        return this.failed(id, "reading the head commit", commit);
      }

      const baseTree = (await commit.json()).tree.sha;

      if (screenshot && !blob) {
        // The base64 goes in as sent: it holds no character JSON escapes, and stringifying
        // megabytes would only copy them.
        const made = await git("POST", "blobs", `{"content":"${screenshot.content}","encoding":"base64"}`);

        if (!made.ok) {
          return this.failed(id, `uploading ${screenshot.name}`, made);
        }

        blob = (await made.json()).sha;
      }

      const entries = report.files.map((file) => ({ path: `reports/${id}/${file.name}`, mode: "100644", type: "blob", ...(file.text !== undefined ? { content: file.text } : { sha: blob }) }));
      const tree = await git("POST", "trees", JSON.stringify({ base_tree: baseTree, tree: entries }));

      if (!tree.ok) {
        return this.failed(id, "making the tree", tree);
      }

      const made = await git("POST", "commits", JSON.stringify({ message: `report ${id}: ${report.title}`, tree: (await tree.json()).sha, parents: [head] }));

      if (!made.ok) {
        return this.failed(id, "making the commit", made);
      }

      const moved = await git("PATCH", `refs/heads/${branch}`, JSON.stringify({ sha: (await made.json()).sha, force: false }));

      if (moved.ok) {
        return null;
      }

      if (moved.status !== 422 || tries >= this.limits.commitTries) {
        return this.failed(id, "moving the branch", moved);
      }

      this.log.info(`report ${id}: the branch moved meanwhile, committing again`);
    }
  }

  /**
   * Sends a request to GitHub's API with one of the relay's tokens.
   *
   * @param {string} method The HTTP method.
   * @param {string} path The path under GITHUB_API.
   * @param {string | undefined} body The JSON body, undefined for a GET.
   * @param {string} token The token the request needs: the issues' or the files' one.
   * @returns {Promise<Response>} GitHub's answer.
   */
  github(method, path, body, token) {
    return this.fetch(`${GITHUB_API}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "mgq-online-relay",
        "Content-Type": "application/json",
      },
      body,
      signal: AbortSignal.timeout(this.limits.githubTimeoutMs),
    });
  }

  /**
   * Logs what GitHub answered to a step it refused, never the token, and makes the refusal.
   *
   * @param {string} id The report.
   * @param {string} step What the relay asked for, such as "opening the issue".
   * @param {Response} answer GitHub's answer.
   * @returns {Promise<{status: number, body: object}>} The refusal.
   */
  async failed(id, step, answer) {
    let message = "";

    try {
      message = String((await answer.json())?.message ?? "").slice(0, 200);
    } catch {
      // An answer without a JSON message still has its status.
    }

    this.log.error(`report ${id}: GitHub answered ${answer.status} to ${step}${message ? `: ${message}` : ""}`);
    return githubFailed();
  }

  /**
   * Makes a new report id: the UTC day and 8 random lowercase hexadecimal characters.
   *
   * @returns {string} The id, such as 2026-10-11-0a1b2c3d.
   */
  newId() {
    return `${new Date(this.clock()).toISOString().slice(0, 10)}-${hexOf(this.random()).slice(0, 8)}`;
  }
}

/**
 * The answer for a player or address past a rate limit.
 *
 * @returns {{status: number, body: object}} The answer.
 */
function tooMany() {
  return { status: 429, body: { error: "too many bug reports, try again later", code: REPORT_REFUSAL.rate } };
}

/**
 * The answer while the relay already handles limits.maxPending reports.
 *
 * @returns {{status: number, body: object}} The answer.
 */
function busy() {
  return { status: 503, body: { error: "the relay is handling other bug reports, try again in a minute", code: REPORT_REFUSAL.busy } };
}

/**
 * The answer for a report GitHub refused or failed to take.
 *
 * @returns {{status: number, body: object}} The answer.
 */
function githubFailed() {
  return { status: 502, body: { error: "GitHub did not take the bug report, try again later", code: REPORT_REFUSAL.github } };
}

/**
 * Answers a request to the report route. The body is read before any refusal, since Cloudflare
 * breaks a request whose object answers before it read the body.
 *
 * @param {ReportDesk} desk The desk.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address.
 * @param {() => Promise<string | null>} readBody Reads the request's body as text, null when it is too large to read.
 * @param {{player?: string | null, address?: string | null}} [client] The PLAYER_HEADER of the request and the address it came from.
 * @returns {Promise<{status: number, body: object}>} The answer.
 */
export async function handleReportRequest(desk, method, url, readBody, client = {}) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);

  if (parts[0] !== VERSION || parts[1] !== "reports" || parts.length !== 2 || method !== "POST") {
    return notFound("route");
  }

  let body;

  try {
    body = await readBody();
  } catch {
    return badRequest("the body could not be read");
  }

  return desk.send(client.player ?? null, client.address ?? null, body);
}
