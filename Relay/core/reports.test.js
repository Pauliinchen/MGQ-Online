//----------------------------------------------------------------
//  reports.test.js
//
//  Changelog:
//      Paulinchen  2026-10-11: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { gzipSync } from "node:zlib";
import { REPORT_DEFAULTS, REPORT_LIMITS, ReportDesk, WindowLimiter, fileLink, handleReportRequest, issueMarkdown, parseReport, reportSettingsOf, unpackFiles } from "./reports.js";

/**
 * The reporting player's key.
 */
const PLAYER = "a1".repeat(16);

/**
 * The address the reports come from.
 */
const ADDRESS = "203.0.113.5";

/**
 * The GitHub token of the desk under test that opens issues.
 */
const TOKEN = "github_pat_test_token";

/**
 * The GitHub token of the desk under test that commits files.
 */
const FILES_TOKEN = "github_pat_test_files_token";

/**
 * Where the desk under test sends reports.
 */
const SETTINGS = Object.freeze({ issuesToken: TOKEN, filesToken: FILES_TOKEN, issuesRepo: "Owner/Issues", filesRepo: "Owner/Files", branch: "main" });

/**
 * The report route's address.
 */
const ROUTE = new URL("https://relay/v1/reports");

/**
 * The zero-width space the relay puts after every "@".
 */
const ZERO_WIDTH_SPACE = String.fromCharCode(0x200b);

/**
 * The base64 of a screenshot, short as a test's.
 */
const SCREENSHOT = "iVBORw0KGgo=";

/**
 * The id the desks under test give their first report, from their clock and random bytes.
 */
const ID = "2026-10-11-0a1b2c3d";

/**
 * The name of the test report's log, with a folder and spaces.
 */
const LOG_NAME = "Logs/Multiplayer InGame 2026-10-11 20-19-33.log";

/**
 * A report's header, valid as it is, without its files.
 */
const HEADER = Object.freeze({
  title: "Formation stays shut",
  text: "After the strategy meeting\nI cannot change my formation.",
  version: "0.6.3",
  facts: [["Mod", "0.6.3"], ["Game", "3.06, translated"], ["World", "Raid"], ["Where", "Scene_Map, map 154"]],
});

/**
 * Packs a text as a game sends it: UTF-8, gzipped unless told otherwise, in base64.
 *
 * @param {string | Uint8Array} text The text, or raw bytes.
 * @param {boolean} [gzip] Whether to gzip it.
 * @returns {{content: string, gzip: boolean}} The base64 and the flag.
 */
function packed(text, gzip = true) {
  const bytes = typeof text === "string" ? Buffer.from(text, "utf8") : Buffer.from(text);
  return { content: (gzip ? gzipSync(bytes) : bytes).toString("base64"), gzip };
}

/**
 * The files of the test report: report.md, the screenshot, a log in a folder and an unzipped text.
 */
const FILES = Object.freeze([
  { name: "report.md", ...packed("# Formation stays shut\n") },
  { name: "screenshot.png", content: SCREENSHOT, gzip: false },
  { name: LOG_NAME, ...packed("12:00 opened the formation\n") },
  { name: "errors.txt", ...packed("no errors", false) },
]);

/**
 * Makes a report's body: its header line, then the files' base64 parts.
 *
 * @param {object} [changes] What differs from HEADER.
 * @param {{name: string, content: string, gzip?: boolean}[]} [files] Each file's name, base64 part and gzip flag.
 * @returns {string} The body.
 */
function bodyOf(changes = {}, files = FILES) {
  const header = { ...HEADER, files: files.map(({ name, content, gzip }) => ({ name, length: content.length, gzip })), ...changes };
  return `${JSON.stringify(header)}\n${files.map(({ content }) => content).join("")}`;
}

/**
 * Makes a stand-in for GitHub's API that records every request and answers as told.
 *
 * @param {(url: string, init: object) => Response | undefined} [answer] Answers a request, GitHub's success unless it returns one.
 * @returns {{fetch: typeof fetch, requests: {url: string, method: string, headers: object, body: string}[]}} The stand-in and its requests.
 */
function fakeGitHub(answer = () => undefined) {
  const requests = [];
  const files = "https://api.github.com/repos/Owner/Files/git/";

  return {
    requests,
    fetch: async (url, init) => {
      requests.push({ url, method: init.method, headers: init.headers, body: init.body });
      const own = answer(url, init);
      const path = url.startsWith(files) ? url.slice(files.length) : url;
      const heads = requests.filter((request) => request.url.endsWith("git/ref/heads/main")).length;

      if (own) {
        return own;
      }

      if (path === "ref/heads/main") return Response.json({ object: { sha: `head${heads}` } });
      if (path.startsWith("commits/")) return Response.json({ tree: { sha: `tree-of-${path.slice(8)}` } });
      if (path === "blobs") return Response.json({ sha: "blob1" }, { status: 201 });
      if (path === "trees") return Response.json({ sha: `tree${heads}` }, { status: 201 });
      if (path === "commits") return Response.json({ sha: `commit${heads}` }, { status: 201 });
      if (path === "refs/heads/main") return Response.json({ object: {} });
      return Response.json({ number: 42, html_url: "https://github.com/Owner/Issues/issues/42" }, { status: 201 });
    },
  };
}

/**
 * Makes a desk over a stand-in GitHub, with a clock the tests move and fixed random bytes.
 *
 * @param {{answer?: (url: string, init: object) => Response | undefined, settings?: object, limits?: typeof REPORT_LIMITS}} [options] How GitHub answers, the settings and the limits.
 * @returns {{desk: ReportDesk, github: ReturnType<typeof fakeGitHub>, time: {now: number}, logged: {info: string[], error: string[]}}} The desk, its GitHub, its clock and what it logged.
 */
function newDesk({ answer, settings = SETTINGS, limits = REPORT_LIMITS } = {}) {
  const github = fakeGitHub(answer);
  const time = { now: Date.UTC(2026, 9, 11, 12) };
  const logged = { info: [], error: [] };
  const log = { info: (line) => logged.info.push(line), error: (line) => logged.error.push(line) };
  const desk = new ReportDesk(settings, { clock: () => time.now, fetch: github.fetch, random: () => Uint8Array.of(0x0a, 0x1b, 0x2c, 0x3d), limits, log });
  return { desk, github, time, logged };
}

/**
 * Sends a report to the route.
 *
 * @param {ReportDesk} desk The desk.
 * @param {string | null} body The body.
 * @param {{player?: string | null, address?: string | null}} [client] The player's key and address.
 * @returns {Promise<{status: number, body: object}>} The answer.
 */
function post(desk, body, client = { player: PLAYER, address: ADDRESS }) {
  return handleReportRequest(desk, "POST", ROUTE, async () => body, client);
}

/**
 * Tells a refusal's status for a body, or undefined when parseReport takes it.
 *
 * @param {string} body The body.
 * @returns {number | undefined} The status.
 */
function refused(body) {
  return parseReport(body).refusal?.status;
}

test("a report's files go to the files repository in one commit, then its issue opens", async () => {
  const { desk, github, logged } = newDesk();
  const answer = await post(desk, bodyOf());

  assert.equal(answer.status, 201);
  assert.deepEqual(answer.body, { issue: 42, url: "https://github.com/Owner/Issues/issues/42", id: ID });

  const git = "https://api.github.com/repos/Owner/Files/git";
  assert.deepEqual(github.requests.map((request) => [request.method, request.url]), [
    ["GET", `${git}/ref/heads/main`],
    ["GET", `${git}/commits/head1`],
    ["POST", `${git}/blobs`],
    ["POST", `${git}/trees`],
    ["POST", `${git}/commits`],
    ["PATCH", `${git}/refs/heads/main`],
    ["POST", "https://api.github.com/repos/Owner/Issues/issues"],
  ]);
  assert.equal(github.requests[0].body, undefined);
  assert.deepEqual(JSON.parse(github.requests[2].body), { content: SCREENSHOT, encoding: "base64" });
  assert.deepEqual(JSON.parse(github.requests[3].body), {
    base_tree: "tree-of-head1",
    tree: [
      { path: `reports/${ID}/report.md`, mode: "100644", type: "blob", content: "# Formation stays shut\n" },
      { path: `reports/${ID}/screenshot.png`, mode: "100644", type: "blob", sha: "blob1" },
      { path: `reports/${ID}/${LOG_NAME}`, mode: "100644", type: "blob", content: "12:00 opened the formation\n" },
      { path: `reports/${ID}/errors.txt`, mode: "100644", type: "blob", content: "no errors" },
    ],
  });
  assert.deepEqual(JSON.parse(github.requests[4].body), { message: `report ${ID}: Formation stays shut`, tree: "tree1", parents: ["head1"] });
  assert.deepEqual(JSON.parse(github.requests[5].body), { sha: "commit1", force: false });

  assert.ok(github.requests.slice(0, 6).every((request) => request.headers.Authorization === `Bearer ${FILES_TOKEN}`), "the files go with the files token");
  const headers = github.requests[6].headers;
  assert.equal(headers.Authorization, `Bearer ${TOKEN}`, "the issue opens with the issues token");
  assert.equal(headers.Accept, "application/vnd.github+json");
  assert.equal(headers["X-GitHub-Api-Version"], "2022-11-28");
  assert.equal(headers["User-Agent"], "mgq-online-relay");

  const issue = JSON.parse(github.requests[6].body);
  assert.equal(issue.title, "[In-game] Formation stays shut");
  assert.deepEqual(issue.labels, ["in-game report"]);
  assert.equal(issue.body, [
    "> After the strategy meeting\n> I cannot change my formation.",
    "| | |\n| --- | --- |\n| Mod | 0.6.3 |\n| Game | 3.06, translated |\n| World | Raid |\n| Where | Scene_Map, map 154 |",
    `Full report (private): [report.md](https://github.com/Owner/Files/blob/main/reports/${ID}/report.md) · [screenshot.png](https://github.com/Owner/Files/blob/main/reports/${ID}/screenshot.png)`,
    `Report \`${ID}\`, sent from the game.`,
  ].join("\n\n"));
  assert.deepEqual(logged.info, [`report ${ID}: opened issue #42`]);
});

test("a report without a screenshot makes no blob and links report.md alone", async () => {
  const { desk, github } = newDesk();
  const answer = await post(desk, bodyOf({}, [FILES[0]]));

  assert.equal(answer.status, 201);
  assert.ok(!github.requests.some((request) => request.url.endsWith("/blobs")));
  const body = JSON.parse(github.requests.at(-1).body).body;
  assert.ok(body.includes(`Full report (private): [report.md](https://github.com/Owner/Files/blob/main/reports/${ID}/report.md)\n`));
  assert.ok(!body.includes("screenshot"));
});

test("a branch another report moved meanwhile is committed on again, up to 3 tries", async () => {
  let moves = 0;
  const once = newDesk({ answer: (url, init) => (init.method === "PATCH" && ++moves === 1 ? Response.json({ message: "Update is not a fast forward" }, { status: 422 }) : undefined) });
  assert.equal((await post(once.desk, bodyOf())).status, 201);

  const methods = once.github.requests.map((request) => `${request.method} ${request.url.split("/git/")[1] ?? "issue"}`);
  assert.deepEqual(methods, ["GET ref/heads/main", "GET commits/head1", "POST blobs", "POST trees", "POST commits", "PATCH refs/heads/main", "GET ref/heads/main", "GET commits/head2", "POST trees", "POST commits", "PATCH refs/heads/main", "POST issue"]);
  assert.deepEqual(JSON.parse(once.github.requests[9].body).parents, ["head2"], "the second commit builds on the new head");
  assert.deepEqual(once.logged.info[0], `report ${ID}: the branch moved meanwhile, committing again`);

  const never = newDesk({ answer: (url, init) => (init.method === "PATCH" ? Response.json({ message: "Update is not a fast forward" }, { status: 422 }) : undefined) });
  const answer = await post(never.desk, bodyOf());
  assert.deepEqual([answer.status, answer.body.code], [502, "github"]);
  assert.equal(never.github.requests.filter((request) => request.method === "PATCH").length, 3);
  assert.ok(!never.github.requests.some((request) => request.url.endsWith("/issues")), "no issue opens without its files");
  assert.deepEqual(never.logged.error, [`report ${ID}: GitHub answered 422 to moving the branch: Update is not a fast forward`]);
});

test("mentions are neutralised, table cells escaped and link paths encoded", () => {
  const report = { text: "ask @someone", facts: [["Where | when", "@team a|b"]], files: [] };
  const markdown = issueMarkdown(report, "2026-10-11-00000000", SETTINGS);

  assert.equal(markdown, `> ask @${ZERO_WIDTH_SPACE}someone\n\n| | |\n| --- | --- |\n| Where \\| when | @${ZERO_WIDTH_SPACE}team a\\|b |\n\nReport \`2026-10-11-00000000\`, sent from the game.`);
  assert.equal(issueMarkdown({ ...report, facts: [] }, "x", SETTINGS), `> ask @${ZERO_WIDTH_SPACE}someone\n\nReport \`x\`, sent from the game.`, "a report without facts has no table");
  assert.equal(fileLink(SETTINGS, ID, LOG_NAME), `https://github.com/Owner/Files/blob/main/reports/${ID}/Logs/Multiplayer%20InGame%202026-10-11%2020-19-33.log`);
  assert.equal(fileLink(SETTINGS, ID, "a+b (1).txt"), `https://github.com/Owner/Files/blob/main/reports/${ID}/a%2Bb%20(1).txt`);
});

test("the issue title is neutralised too", async () => {
  const { desk, github } = newDesk();
  await post(desk, bodyOf({ title: "  @here it broke  " }));
  assert.equal(JSON.parse(github.requests.at(-1).body).title, `[In-game] @${ZERO_WIDTH_SPACE}here it broke`);
});

test("an issue GitHub refuses over its label is opened again without labels", async () => {
  let refusedOnce = false;
  const { desk, github } = newDesk({
    answer: (url, init) => {
      if (url.endsWith("/issues") && !refusedOnce) {
        refusedOnce = true;
        return Response.json({ message: "Validation Failed", errors: [{ resource: "Label", code: "invalid" }] }, { status: 422 });
      }

      return undefined;
    },
  });

  const answer = await post(desk, bodyOf());
  assert.equal(answer.status, 201);
  const issues = github.requests.filter((request) => request.url.endsWith("/issues")).map((request) => JSON.parse(request.body));
  assert.deepEqual(issues.map((issue) => issue.labels), [["in-game report"], undefined]);
});

test("a step GitHub refuses ends the report with 502, logs GitHub's status and never a token", async () => {
  const steps = [
    ["ref/heads/main", "reading the branch"],
    ["commits/head1", "reading the head commit"],
    ["blobs", "uploading screenshot.png"],
    ["trees", "making the tree"],
    ["git/commits", "making the commit"],
    ["refs/heads/main", "moving the branch"],
  ];

  for (const [ending, step] of steps) {
    const { desk, github, logged } = newDesk({ answer: (url) => (url.endsWith(ending) ? Response.json({ message: "Bad credentials" }, { status: 401 }) : undefined) });
    const answer = await post(desk, bodyOf());

    assert.deepEqual([answer.status, answer.body.code], [502, "github"]);
    assert.ok(!github.requests.some((request) => request.url.endsWith("/issues")), "no issue opens without its files");
    assert.deepEqual(logged.error, [`report ${ID}: GitHub answered 401 to ${step}: Bad credentials`]);
    assert.ok(!JSON.stringify(logged).includes(TOKEN) && !JSON.stringify(logged).includes(FILES_TOKEN));
  }

  const issueRefused = newDesk({ answer: (url) => (url.endsWith("/issues") ? new Response("oops", { status: 500 }) : undefined) });
  assert.equal((await post(issueRefused.desk, bodyOf())).status, 502);
  assert.deepEqual(issueRefused.logged.error, [`report ${ID}: GitHub answered 500 to opening the issue`]);

  const unlabelled = newDesk({ answer: (url) => (url.endsWith("/issues") ? Response.json({ message: "Validation Failed: title" }, { status: 422 }) : undefined) });
  assert.equal((await post(unlabelled.desk, bodyOf())).status, 502);
  assert.equal(unlabelled.github.requests.filter((request) => request.url.endsWith("/issues")).length, 1, "a 422 about something else is not tried again");
});

test("an unreachable GitHub ends the report with 502", async () => {
  const { desk, logged } = newDesk({
    answer: () => {
      throw new TypeError("fetch failed");
    },
  });

  const answer = await post(desk, bodyOf());
  assert.deepEqual([answer.status, answer.body.code], [502, "github"]);
  assert.deepEqual(logged.error, [`report ${ID}: GitHub could not be reached or answered unreadably: fetch failed`]);
});

test("without both GitHub tokens the relay takes no reports", async () => {
  for (const settings of [{ ...SETTINGS, filesToken: null }, { ...SETTINGS, issuesToken: "" }]) {
    const { desk, github } = newDesk({ settings });
    const answer = await post(desk, bodyOf());

    assert.deepEqual(answer, { status: 503, body: { error: "bug reports are off on this relay", code: "off" } });
    assert.equal(github.requests.length, 0);
  }
});

test("a report needs a player key", async () => {
  const { desk } = newDesk();

  for (const player of [null, "", "A1".repeat(16), "a1".repeat(15)]) {
    const answer = await post(desk, bodyOf(), { player, address: ADDRESS });
    assert.deepEqual([answer.status, answer.body.code], [401, "player"]);
  }
});

test("a body too large to read, or longer than the limit, is answered with 413", async () => {
  const { desk } = newDesk();
  assert.equal((await post(desk, null)).status, 413);

  const small = new ReportDesk(SETTINGS, { limits: { ...REPORT_LIMITS, maxBodyBytes: 100 } });
  assert.equal((await post(small, bodyOf())).status, 413);
});

test("only POST /v1/reports is a route", async () => {
  const { desk } = newDesk();
  assert.equal((await handleReportRequest(desk, "GET", ROUTE, async () => "")).status, 404);
  assert.equal((await handleReportRequest(desk, "POST", new URL("https://relay/v1/reports/x"), async () => bodyOf())).status, 404);
  assert.equal((await handleReportRequest(desk, "POST", new URL("https://relay/v1/report"), async () => bodyOf())).status, 404);
});

test("a player sends at most 3 reports an hour and 10 a day, and an address 6 an hour", async () => {
  const { desk, time } = newDesk();
  const send = (player, address = ADDRESS) => post(desk, bodyOf(), { player, address });
  const hour = 60 * 60 * 1000;

  for (let count = 0; count < 3; count++) {
    assert.equal((await send(PLAYER, null)).status, 201);
  }

  const limited = await send(PLAYER, null);
  assert.deepEqual([limited.status, limited.body.code], [429, "rate"]);

  for (let hours = 1; hours <= 3; hours++) {
    time.now += hour;

    for (let count = 0; count < (hours === 3 ? 1 : 3); count++) {
      assert.equal((await send(PLAYER, null)).status, 201);
    }
  }

  time.now += hour;
  assert.equal((await send(PLAYER, null)).status, 429, "the eleventh report of a day");
  time.now += 24 * hour;
  assert.equal((await send(PLAYER, null)).status, 201);

  const others = Array.from({ length: 7 }, (_, index) => (index + 16).toString(16).repeat(16));

  for (const other of others.slice(0, 6)) {
    assert.equal((await send(other)).status, 201);
  }

  assert.equal((await send(others[6])).status, 429, "the seventh report of an address within an hour");
  assert.equal((await send(others[6], "198.51.100.7")).status, 201);
});

test("a refused report counts against no rate limit", async () => {
  const { desk } = newDesk();

  for (let count = 0; count < 5; count++) {
    assert.equal((await post(desk, bodyOf({ title: "" }))).status, 400);
    assert.equal((await post(desk, bodyOf({}, [{ name: "report.md", content: "AAAA", gzip: true }]))).status, 400);
  }

  assert.equal((await post(desk, bodyOf())).status, 201);
});

test("every rule of the header is checked", () => {
  const many = Array.from({ length: 13 }, (_, index) => [`Fact ${index}`, "x"]);

  assert.ok(parseReport(bodyOf()).report);
  assert.equal(refused(`${"x".repeat(REPORT_LIMITS.maxHeaderLength + 1)}\n`), 400);
  assert.equal(refused("not json\n"), 400);
  assert.equal(refused("[1, 2]\n"), 400);
  assert.equal(refused(bodyOf({ title: "   " })), 400);
  assert.equal(refused(bodyOf({ title: "x".repeat(101) })), 400);
  assert.equal(refused(bodyOf({ title: "two\nlines" })), 400);
  assert.equal(refused(bodyOf({ title: 7 })), 400);
  assert.equal(refused(bodyOf({ text: " \n " })), 400);
  assert.equal(refused(bodyOf({ text: "x".repeat(4001) })), 400);
  assert.equal(refused(bodyOf({ version: "" })), 400);
  assert.equal(refused(bodyOf({ version: "0.6.3 beta" })), 400);
  assert.equal(refused(bodyOf({ version: "1".repeat(33) })), 400);
  assert.equal(refused(bodyOf({ facts: many })), 400);
  assert.equal(refused(bodyOf({ facts: [["", "x"]] })), 400);
  assert.equal(refused(bodyOf({ facts: [["x".repeat(33), "x"]] })), 400);
  assert.equal(refused(bodyOf({ facts: [["Where", "x".repeat(121)]] })), 400);
  assert.equal(refused(bodyOf({ facts: [["Where", "a\nb"]] })), 400);
  assert.equal(refused(bodyOf({ facts: [["Where"]] })), 400);
  assert.equal(refused(bodyOf({ facts: "Mod 0.6.3" })), 400);
  assert.ok(parseReport(bodyOf({ facts: [["Development build", ""]] })).report, "a value may be empty");
});

test("every rule of the files is checked", () => {
  const index = FILES[0];
  const text = (name, gzip = false) => ({ name, ...packed("x", gzip) });
  const withIndex = (...files) => bodyOf({}, [index, ...files]);

  assert.equal(refused(bodyOf({}, [])), 400, "report.md is required");
  assert.equal(refused(bodyOf({ files: "report.md" }, [])), 400);
  assert.equal(refused(bodyOf({}, [text("notes.txt")])), 400, "report.md is required");
  assert.equal(refused(withIndex(index)), 400, "report.md once");
  assert.equal(refused(withIndex(text("Errors.txt"), text("errors.TXT"))), 400, "names are unique whatever their case");
  assert.equal(refused(withIndex(...Array.from({ length: 32 }, (_, number) => text(`log ${number}.log`)))), 400, "at most 32 files");
  assert.ok(parseReport(withIndex(...Array.from({ length: 31 }, (_, number) => text(`log ${number}.log`)))).report);

  assert.equal(refused(withIndex(text(`${"x".repeat(117)}.txt`))), 400, "names of at most 120 characters");
  assert.ok(parseReport(withIndex(text(`${"x".repeat(116)}.txt`))).report);
  assert.equal(refused(withIndex(text("Logs/More/deep.log"))), 400, "one folder at most");
  assert.equal(refused(withIndex(text("/root.log"))), 400);
  assert.equal(refused(withIndex(text("Logs/"))), 400);
  assert.equal(refused(withIndex(text(".hidden.log"))), 400);
  assert.equal(refused(withIndex(text("../up.log"))), 400);
  assert.equal(refused(withIndex(text("Logs/../up.log"))), 400);
  assert.equal(refused(withIndex(text("a:b.log"))), 400);
  assert.equal(refused(withIndex(text("a\\b.log"))), 400);
  assert.ok(parseReport(withIndex(text("Logs/a_b (1)+c-d.LOG"), text("notes.md"))).report);

  assert.equal(refused(withIndex(text("notes.pdf"))), 400, "every file but the screenshot is text");
  assert.equal(refused(withIndex(text("Logs/screenshot.png"))), 400);
  assert.equal(refused(withIndex({ name: "screenshot.png", content: SCREENSHOT, gzip: true })), 400, "the screenshot is never gzipped");
  assert.equal(refused(bodyOf({ files: [{ name: "report.md", length: 4, gzip: "yes" }] }, [{ name: "report.md", content: "AAAA" }])), 400);

  assert.equal(refused(bodyOf({ files: [{ name: "report.md", length: 15 }] }, [{ name: "report.md", content: "x".repeat(15) }])), 400);
  assert.equal(refused(bodyOf({ files: [{ name: "report.md", length: 0 }] }, [])), 400);
  assert.equal(refused(bodyOf({ files: [{ name: "report.md", length: 4 }] }, [{ name: "report.md", content: "AAAAAAAA" }])), 400, "the lengths fall short of the body");
  assert.equal(refused(bodyOf({}, [{ name: "report.md", content: "UEs=DBBQ" }])), 400, "padding only at the end");
  assert.equal(refused(bodyOf({}, [{ name: "report.md", content: "UEs*DBBQ" }])), 400);
  assert.equal(refused(bodyOf({ files: [{ name: "report.md", length: 4 }, { name: "screenshot.png", length: 4 * 1024 * 1024 + 4 }] }, [])), 413);
});

test("a report's fields are read trimmed, and its parts cut where the header says", () => {
  const { report } = parseReport(bodyOf({ title: "  Stuck\t ", text: "\r\n Line one\r\nLine two \n" }));

  assert.equal(report.title, "Stuck");
  assert.equal(report.text, "Line one\nLine two");
  assert.deepEqual(report.files, FILES.map(({ name, content, gzip }) => ({ name, gzip, content })));
});

test("text files are unpacked to UTF-8 with replacement characters, the screenshot kept as sent", async () => {
  const files = [
    { name: "report.md", gzip: true, content: packed("Bericht äöü 日本").content },
    { name: "errors.txt", gzip: false, content: packed(Uint8Array.of(0x61, 0xff, 0x62), false).content },
    { name: "screenshot.png", gzip: false, content: SCREENSHOT },
    { name: "empty.log", gzip: true, content: packed("").content },
  ];

  assert.deepEqual(await unpackFiles(files), {
    files: [
      { name: "report.md", text: "Bericht äöü 日本" },
      { name: "errors.txt", text: "a�b" },
      { name: "screenshot.png", content: SCREENSHOT },
      { name: "empty.log", text: "" },
    ],
  });
});

test("a gzip stream that does not unpack is refused with 400", async () => {
  const whole = packed("a line of the log\n".repeat(50)).content;
  const cut = Buffer.from(whole, "base64").subarray(0, 30).toString("base64");

  for (const content of [packed("not gzip", false).content, cut]) {
    const answer = await unpackFiles([{ name: "report.md", gzip: true, content }]);
    assert.equal(answer.refusal.status, 400);
  }

  const { desk, github } = newDesk();
  assert.equal((await post(desk, bodyOf({}, [{ name: "report.md", ...packed("plain", false), gzip: true }]))).status, 400);
  assert.equal(github.requests.length, 0);
});

test("a text file past 8 MiB unpacked, or all of them past 24 MiB together, is refused with 413", async () => {
  const bomb = packed(new Uint8Array(REPORT_LIMITS.maxTextBytes + 1)).content;
  assert.ok(bomb.length < 64 * 1024, "the bomb is small packed");
  const answer = await unpackFiles([{ name: "report.md", gzip: true, content: bomb }]);
  assert.equal(answer.refusal.status, 413);
  assert.match(answer.refusal.body.error, /a text file may have at most 8388608 bytes/);
  assert.ok((await unpackFiles([{ name: "report.md", gzip: true, content: packed(new Uint8Array(REPORT_LIMITS.maxTextBytes)).content }])).files, "8 MiB itself is taken");

  const limits = { ...REPORT_LIMITS, maxTextBytes: 100, maxTextBytesTotal: 150 };
  const file = (name, size, gzip = true) => ({ name, gzip, content: packed("x".repeat(size), gzip).content });
  assert.ok((await unpackFiles([file("report.md", 100), file("a.log", 50, false)], limits)).files);
  assert.equal((await unpackFiles([file("report.md", 101, false)], limits)).refusal.status, 413, "unzipped text counts too");

  const together = await unpackFiles([file("report.md", 100), file("a.log", 51)], limits);
  assert.equal(together.refusal.status, 413);
  assert.match(together.refusal.body.error, /together/);

  const { desk, github } = newDesk({ limits });
  assert.equal((await post(desk, bodyOf({}, [file("report.md", 100), file("a.log", 51)]))).status, 413);
  assert.equal(github.requests.length, 0);
});

test("the window limiter forgets turns older than its window and the least recent keys", () => {
  const time = { now: 0 };
  const limiter = new WindowLimiter({ max: 2, windowMs: 100 }, () => time.now, 2);

  limiter.take("a");
  limiter.take("a");
  assert.equal(limiter.allows("a"), false);
  assert.equal(limiter.allows(null), true);
  time.now = 100;
  assert.equal(limiter.allows("a"), true);

  limiter.take("b");
  limiter.take("c");
  assert.deepEqual([...limiter.turns.keys()], ["b", "c"]);
});

test("the settings fall back to the default repositories and branch", () => {
  assert.deepEqual(reportSettingsOf({}), { issuesToken: null, filesToken: null, ...REPORT_DEFAULTS });
  assert.deepEqual(reportSettingsOf({ GITHUB_ISSUES_TOKEN: " t ", GITHUB_BUG_FILES_TOKEN: "f", REPORT_ISSUES_REPO: "A/B", REPORT_FILES_REPO: "C/D", REPORT_FILES_BRANCH: "reports" }), { issuesToken: "t", filesToken: "f", issuesRepo: "A/B", filesRepo: "C/D", branch: "reports" });
  assert.deepEqual(reportSettingsOf({ REPORT_FILES_BRANCH: "" }).branch, "main");
});
