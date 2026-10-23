//----------------------------------------------------------------
//  story_catchup.js
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

// The catch-up's tables beside the story mapping, kept and served by the same engine
// (story_mapping.js): what carries a Raid World player who falls behind along with the world's
// story (world_catchup_data.rbx and world_catchup.rbx), and the rewards of the game's events a
// party member catches up with (coop_story_rewards.rbx). Each row holds every field the game
// reads of the Ruby row it replaces.
//
// A row's place in the story is its part, its step there (variable 1001 in Parts 1 to 3, the
// route's variable 1141, 1142 or 1143 on a route; null where nothing tells it), the side it asks
// for and its marks: what holds in the story once its event ran. A row's `ran` tells whether its
// marks show that its event ran, false where they only show that the event is there to play.

import { PART } from "./story.js";
import { EVENT_FIELD, FLAG, ID, MAP, MAPPING_REFUSAL, MAPPING_TABLES, MARKS, SELF_SWITCH_FIELD, SITE_FIELD, STEP, VALUE, listOf, nullable, oneOf, whole } from "./story_mapping.js";

/**
 * Reads a part of the story as the relay names it.
 */
const PART_FIELD = oneOf(Object.values(PART));

/**
 * Reads a level, such as a join's gate or a class's level.
 */
const LEVEL = whole(1, 9999);

/**
 * The most entries of a list of ids a row holds.
 */
const MAX_IDS = 64;

/**
 * A character a name may not hold: a control character or a line break.
 */
const CONTROL_CHARACTER = /[\u0000-\u001f\u007f]/;

/**
 * Reads a part's name: a text of 1 to 40 characters on one line.
 */
const NAME = Object.freeze({
  what: "a text of 1 to 40 characters on one line",
  read: (value) => (typeof value === "string" && value.trim() === value && value.length >= 1 && value.length <= 40 && !CONTROL_CHARACTER.test(value) ? value : undefined),
});

/**
 * Reads a whole number other than 0, such as an amount given (above 0) or taken (below 0).
 *
 * @param {number} most The most given or taken.
 * @returns {import("./story_mapping.js").FieldReader} The reader.
 */
function amount(most) {
  const reader = whole(-most, most);
  return { what: `a whole number of ${-most} to ${most} other than 0`, read: (value) => (value === 0 ? undefined : reader.read(value)) };
}

/**
 * Reads a setting's value: true or false for a switch and the random encounters, a whole number
 * for a variable.
 */
const SETTING_VALUE = Object.freeze({
  what: `true, false or ${VALUE.what}`,
  read: (value) => (typeof value === "boolean" ? value : VALUE.read(value)),
});

/**
 * The fields of a row's place in the story: the event's site, its part, step, side and marks.
 */
const PLACE = Object.freeze({
  site: SITE_FIELD,
  part: nullable(PART_FIELD),
  step: nullable(STEP),
  side: nullable(oneOf(["alice", "ilias"])),
  marks: MARKS,
});

/**
 * Reads what one side of a side event gives: `{skills, companions}`.
 */
const SIDE_REWARDS = Object.freeze({
  what: `an object of skills and companions, each a list of 0 to ${MAX_IDS} ids`,
  read: (value) => {
    const ids = listOf(ID, 0, MAX_IDS);
    const ok = value && typeof value === "object" && !Array.isArray(value) && Object.keys(value).length === 2;
    const skills = ok ? ids.read(value.skills) : undefined;
    const companions = ok ? ids.read(value.companions) : undefined;
    return skills && companions ? { skills, companions } : undefined;
  },
});

/**
 * The catch-up's tables, each named after the Ruby table it replaces.
 *
 * @type {Object<string, import("./story_mapping.js").TableSpec>}
 */
export const CATCHUP_TABLES = Object.freeze({
  // PARTS: the story's parts in their order, each with the marks that hold right before its
  // ending starts and its level gate.
  parts: Object.freeze({
    store: "story_catchup_parts",
    ordered: true,
    key: (row) => row.id,
    fields: Object.freeze({ id: PART_FIELD, name: NAME, ending: MARKS, gate: LEVEL }),
  }),
  // JOINS: every story join of a companion: the main persona, the persona the event adds, the
  // place, the highest base level a player needs, the rule that gave it, and the command's index
  // in its list, which orders the join against a removal of the same list.
  joins: Object.freeze({
    store: "story_catchup_joins",
    ordered: true,
    fields: Object.freeze({ actor: ID, persona: ID, ...PLACE, gate: whole(0, 9999), rule: oneOf(["floor", "start", "cap", "kept"]), index: whole(0, 99_999), ran: FLAG }),
  }),
  // REMOVALS: every removal of a companion by the story outside the player's own choices, and
  // whether only a first playthrough takes them (`first`, for the removals that last).
  removals: Object.freeze({
    store: "story_catchup_removals",
    ordered: true,
    fields: Object.freeze({ actor: ID, persona: ID, ...PLACE, first: FLAG, index: whole(0, 99_999) }),
  }),
  // KEY_ITEMS: every key item the story's events give (above 0) or take (below 0), outside chests;
  // rows that give come before those that take at one place.
  key_items: Object.freeze({
    store: "story_catchup_key_items",
    ordered: true,
    fields: Object.freeze({ item: ID, amount: amount(999), ...PLACE, ran: FLAG }),
  }),
  // CHESTS: the chests that hold key items, which open once for the whole world, with the chest
  // flags they turn on for each player.
  chests: Object.freeze({
    store: "story_catchup_chests",
    ordered: true,
    key: (row) => row.key,
    fields: Object.freeze({ key: SELF_SWITCH_FIELD, items: listOf(ID, 1, MAX_IDS), part: nullable(PART_FIELD), step: nullable(STEP), flags: listOf(ID, 0, MAX_IDS) }),
  }),
  // REWARDS: every skill Luka learns and item the story and its side quests give, key items
  // aside (Ruby's :skill, :i, :w and :a).
  rewards: Object.freeze({
    store: "story_catchup_rewards",
    ordered: true,
    fields: Object.freeze({ kind: oneOf(["skill", "item", "weapon", "armor"]), id: ID, amount: amount(9999), ...PLACE, ran: FLAG }),
  }),
  // LESSONS: every skill the story and its quests teach a companion's persona.
  lessons: Object.freeze({
    store: "story_catchup_lessons",
    ordered: true,
    fields: Object.freeze({ actor: ID, skill: ID, ...PLACE, ran: FLAG }),
  }),
  // CLASS_LEVELS: every class and race the story and its quests give a character at a level.
  class_levels: Object.freeze({
    store: "story_catchup_class_levels",
    ordered: true,
    fields: Object.freeze({ actor: ID, class: ID, level: LEVEL, ...PLACE, ran: FLAG }),
  }),
  // SETTINGS: every setting of the player's own values by the story's events: a variable, a switch
  // or whether random encounters are on (id 0).
  settings: Object.freeze({
    store: "story_catchup_settings",
    ordered: true,
    fields: Object.freeze({ kind: oneOf(["variable", "switch", "encounters"]), id: whole(0, 99_999), value: SETTING_VALUE, ...PLACE, ran: FLAG }),
    check: (row) => {
      const ok = row.kind === "variable" ? row.id > 0 && typeof row.value === "number" : (row.id > 0) === (row.kind === "switch") && typeof row.value === "boolean";
      return ok ? null : { error: "a variable takes an id and a whole number, a switch an id and true or false, the encounters id 0 and true or false", code: MAPPING_REFUSAL.field };
    },
  }),
  // VEHICLES: every event placed in the story that puts a vehicle on a map.
  vehicles: Object.freeze({
    store: "story_catchup_vehicles",
    ordered: true,
    fields: Object.freeze({ vehicle: oneOf(["boat", "ship", "airship"]), ...PLACE, ran: FLAG }),
  }),
  // WARP_FREE_MAPS: the maps where a warp ban (switch 100) left on while no event runs is left
  // over.
  warp_free_maps: Object.freeze({
    store: "story_catchup_warp_free_maps",
    key: (row) => String(row.map),
    fields: Object.freeze({ map: MAP }),
  }),
  // MAKINA: every Makina, the level a player reaches it at and the easiest place that gives it.
  makina: Object.freeze({
    store: "story_catchup_makina",
    key: (row) => String(row.item),
    fields: Object.freeze({ item: ID, level: LEVEL, site: SITE_FIELD }),
  }),
  // COMPANION_VALUES (world_catchup.rbx): the least a variable holds once a companion is in the
  // roster, which their own join stands for.
  companion_values: Object.freeze({
    store: "story_catchup_companion_values",
    key: (row) => `${row.actor}:${row.variable}`,
    fields: Object.freeze({ actor: ID, variable: ID, atLeast: VALUE }),
  }),
  // coop_story_rewards.rbx SKILLS, ACTORS and ITEMS with SIDED, ROUTE and FINAL: what the game's
  // events give a party member who catches up. `most` is how many of an item the events that move
  // the story on give at most; `sided` comes only with the events where the sides differ before
  // the Great Decision, `route` comes from the Final Chapter's events too, `final` only along one
  // route.
  event_rewards: Object.freeze({
    store: "story_catchup_event_rewards",
    key: (row) => `${row.kind}:${row.id}`,
    fields: Object.freeze({ kind: oneOf(["skill", "companion", "item", "weapon", "armor"]), id: ID, most: nullable(whole(1, 9999)), sided: FLAG, route: FLAG, final: FLAG }),
    check: (row) => {
      const item = !["skill", "companion"].includes(row.kind);

      if (item !== (row.most !== null)) {
        return { error: "an item, weapon or armor takes most, a skill or companion takes none", code: MAPPING_REFUSAL.field };
      }

      return (item && row.sided) || (row.route && !row.sided) ? { error: "only a skill or companion is sided, and only a sided one comes by route", code: MAPPING_REFUSAL.field } : null;
    },
  }),
  // coop_story_rewards.rbx GROUPS: the events that give each side other skills or companions
  // before the Great Decision, whether the event is where the player chooses a side, and the marks
  // each of its pages leaves once it ran.
  side_events: Object.freeze({
    store: "story_catchup_side_events",
    key: (row) => row.site,
    fields: Object.freeze({ site: EVENT_FIELD, alice: SIDE_REWARDS, ilias: SIDE_REWARDS, choice: FLAG, marks: listOf(MARKS, 0, MAX_IDS) }),
  }),
});

/**
 * Every table the relay keeps beside the story mapping's own: the mapping's and the catch-up's.
 *
 * @type {Object<string, import("./story_mapping.js").TableSpec>}
 */
export const STORY_TABLES = Object.freeze({ ...MAPPING_TABLES, ...CATCHUP_TABLES });
