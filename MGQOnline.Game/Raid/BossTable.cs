//----------------------------------------------------------------
//  BossTable.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Frozen;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Raid;

/// <summary>
/// The story's boss battles and the raid bosses, by troop: each troop's milestone, its level cap and
/// last phase, the raid bosses' tiers, sections, bar titles and pool keys, and the markers that tell
/// a milestone beaten. <see cref="BossRules"/> decides by them.
/// </summary>
/// <remarks>
/// The game keeps no list of its own, only <see cref="BossSwitch"/>, so the table holds every phase
/// of a fight with several and the bosses a milestone's quest fights before it.
/// </remarks>
public static class BossTable
{
    /// <summary>
    /// The switch the game's events turn on right before every story boss battle and off right after it.
    /// </summary>
    public const int BossSwitch = 22;

    /// <summary>
    /// The section of the one-time bosses of <see cref="Optional"/>, after the story's.
    /// </summary>
    public const string OptionalSection = "Chaos Domain";

    /// <summary>
    /// The longest pool key of a boss, which leaves room for the enemy's number the relay's key of
    /// one enemy of several adds.
    /// </summary>
    public const int MaxKeyLength = 60;

    /// <summary>
    /// A troop's last phase that holds only while a switch is on.
    /// </summary>
    private const int Earlier = 0;

    /// <summary>
    /// A troop that is its fight's last phase.
    /// </summary>
    private const int Last = -1;

    /// <summary>
    /// The story's boss troops in story order. Salamander's fight ends with troop 751 on Luka's side
    /// (switch 4) and goes on to Granberia (752) on Alice's. Troop 1675 ends both the Angelic
    /// Dominion and the Monster Realm milestone of that name.
    /// </summary>
    private static readonly RaidBoss[] Story =
    [
        new(26, "Four bandits", 10, Earlier),
        new(27, "Four bandits", 10, Earlier),
        new(28, "Four bandits", 10, Earlier),
        new(29, "Four bandits", 10, Last),
        new(71, "Queen Harpy", 15, Last),
        new(126, "Morrigan", 18, Last),
        new(196, "Chrome and Frederica", 20, Last),
        new(212, "Sylph", 20, Last),
        new(247, "Sphinx", 20, Last),
        new(248, "Sara", 20, Last),
        new(249, "Astaroth", 20, Last),
        new(299, "Gnome", 20, Last),
        new(327, "Adramelech", 25, Last),
        new(588, "Bonnie and Ashel", 25, Last),
        new(607, "Alma Elma, then Granberia", 30, Earlier),
        new(608, "Alma Elma, then Granberia", 30, Earlier),
        new(609, "Alma Elma, then Granberia", 30, Earlier),
        new(610, "Alma Elma, then Granberia", 30, Last),
        new(655, "Mephisto", 30, Last),
        new(670, "Tezcatlipoca", 30, Last),
        new(672, "Gnosis", 30, Last),
        new(673, "Zion", 30, Last),
        new(678, "Undine", 30, Last),
        new(705, "Lilith", 35, Earlier),
        new(718, "Queen Ant", 30, Last),
        new(874, "Lilith", 35, Earlier),
        new(719, "Lilith", 35, Last),
        new(751, "Salamander", 40, 4),
        new(752, "Salamander", 40, Last),
        new(784, "Queen Fairy", 40, Last),
        new(785, "Queen Elf", 43, Last),
        new(793, "Queen Alraune, then Aži Dahāka", 43, Earlier),
        new(794, "Queen Alraune, then Aži Dahāka", 43, Last),
        new(801, "Queen Mermaid", 45, Earlier),
        new(802, "Queen Mermaid", 45, Last),
        new(807, "Spider Princess", 47, Last),
        new(812, "Carmilla", 47, Last),
        new(813, "Elizabeth", 47, Last),
        new(814, "Queen Vampire", 50, Last),
        new(871, "La Croix's zombies", 50, Earlier),
        new(872, "La Croix's zombies", 50, Last),
        new(836, "Black Dahlia, Black Mamba and Black Rose", 55, Last),
        new(837, "Black Alice", 65, Earlier),
        new(838, "Black Alice", 65, Earlier),
        new(839, "Black Alice", 65, Last),
        new(854, "Eden", 55, Last),
        new(868, "Sonya Mazda", 55, Last),
        new(869, "Sonya Mainyu", 55, Last),
        new(870, "Sonya Chaos", 55, Last),
        new(1451, "Garuda", 60, Last),
        new(1461, "Erubetie", 60, Last),
        new(1501, "Black Dahlia, Black Mamba and Black Rose", 60, Last),
        new(1502, "Tamamo", 61, Last),
        new(1503, "Erubetie", 62, Last),
        new(1504, "Granberia", 63, Last),
        new(1505, "Great Decision", 65, Earlier),
        new(1506, "Great Decision", 65, Earlier),
        new(1507, "Great Decision", 65, Last),
        new(1508, "Great Decision", 65, Earlier),
        new(1509, "Great Decision", 65, Last),
        new(1517, "Heaven's Gate", 67, Last),
        new(1544, "Gabriela", 70, Last),
        new(1554, "Uriela, Sabiriel and Fernandez", 75, Earlier),
        new(1557, "Uriela, Sabiriel and Fernandez", 75, Earlier),
        new(1558, "Uriela, Sabiriel and Fernandez", 75, Last),
        new(1564, "Sariela", 78, Last),
        new(1590, "Laplace", 80, Last),
        new(1592, "Metatronne and Sandalphone", 83, Earlier),
        new(1599, "Metatronne and Sandalphone", 83, Last),
        new(1610, "Zion (three fights)", 85, Earlier),
        new(1611, "Zion (three fights)", 85, Earlier),
        new(1612, "Zion (three fights)", 85, Last),
        new(1634, "Cosmos", 90, Earlier),
        new(1635, "Cosmos", 90, Last),
        new(1642, "Aži Dahāka", 95, Last),
        new(1659, "Marcellus and Black Alice", 95, Earlier),
        new(1660, "Marcellus and Black Alice", 95, Last),
        new(1674, "Doppel Lukas and Lucifina", 100, Earlier),
        new(1675, "Doppel Lukas and Lucifina", 100, Last),
        new(1722, "Micaela", 105, Last),
        new(1723, "Ilias", 115, Last),
        new(1724, "Chaos Ilias", 120, Earlier),
        new(1725, "Chaos Ilias", 120, Last),
        new(1745, "Queen Eva", 67, Last),
        new(1763, "Malboro Girl, then Kanon", 70, Earlier),
        new(1769, "Malboro Girl, then Kanon", 70, Last),
        new(1784, "Kanade", 75, Last),
        new(1807, "Tamamo", 80, Last),
        new(1814, "Tamamo", 83, Last),
        new(1847, "Minagi and Alipheese the 10th", 85, Earlier),
        new(1848, "Minagi and Alipheese the 10th", 85, Last),
        new(1869, "Kagetsumugi and her dolls", 90, Last),
        new(1891, "Hiruko", 95, Last),
        new(1902, "Kagetsumugi and Magatsu-Karura, then Black Alice", 95, Earlier),
        new(1903, "Kagetsumugi and Magatsu-Karura, then Black Alice", 95, Last),
        new(1943, "Saja", 105, Last),
        new(1944, "Alipheese", 115, Last),
        new(1945, "Chaos Alipheese", 120, Earlier),
        new(1946, "Chaos Alipheese", 120, Last),
        new(1959, "Kagetsumugi and her dolls", 125, Last),
        new(1975, "Angolmois", 130, Last),
        new(2042, "Greedy Papi, Gob, Teeny and Vanilla", 135, Earlier),
        new(2091, "Greedy Papi, Gob, Teeny and Vanilla", 135, Earlier),
        new(2092, "Greedy Papi, Gob, Teeny and Vanilla", 135, Last),
        new(1983, "Gabriela and Kanon", 135, Earlier),
        new(1984, "Gabriela and Kanon", 135, Last),
        new(1987, "Uriela", 135, Last),
        new(1989, "Kanade", 140, Last),
        new(1995, "Hiruko", 140, Earlier),
        new(1996, "Hiruko", 140, Last),
        new(2001, "Magatsu-Omikami", 145, Last),
        new(1999, "Apiro Lagos", 147, Last),
        new(2003, "Zion and Laplace", 151, Earlier),
        new(2004, "Zion and Laplace", 151, Last),
        new(2005, "Sigrdrifa", 153, Last),
        new(2006, "Metatronne and Sandalphone, then Singularity", 155, Earlier),
        new(2010, "Metatronne and Sandalphone, then Singularity", 155, Last),
        new(2016, "Sisel, EX-Kyubi, Frere and Bloody Dragon", 160, Last),
        new(2017, "Sisel, EX-Kyubi, Frere and Bloody Dragon", 160, Last),
        new(2018, "Sisel, EX-Kyubi, Frere and Bloody Dragon", 160, Last),
        new(2019, "Sisel, EX-Kyubi, Frere and Bloody Dragon", 160, Last),
        new(2029, "Saja", 168, Last),
        new(2047, "World Drown", 175, Last),
        new(2053, "Cosmos", 180, Last),
        new(2054, "No Life King", 185, Earlier),
        new(2061, "No Life King", 185, Last),
        new(2062, "Angolmois", 190, Last),
        new(2221, "Hiruko, Kanon and Kanade", 195, Last),
        new(2090, "Baal Zebub", 203, Last),
        new(2095, "Seven Deadly Sins vessels", 210, Last),
        new(2096, "Seven Deadly Sins vessels", 210, Last),
        new(2097, "Seven Deadly Sins vessels", 210, Last),
        new(2098, "Seven Deadly Sins vessels", 210, Earlier),
        new(2099, "Seven Deadly Sins vessels", 210, Last),
        new(2102, "Seven Deadly Sins vessels", 210, Last),
        new(2107, "Greedy, Envious and Slothful Eva", 213, Earlier),
        new(2108, "Greedy, Envious and Slothful Eva", 213, Earlier),
        new(2109, "Greedy, Envious and Slothful Eva", 213, Last),
        new(2110, "Seven Deadly Sins", 215, Last),
        new(2133, "The All-Knowing", 220, Last),
        new(2224, "Agaliarept", 225, Earlier),
        new(2225, "Agaliarept", 225, Earlier),
        new(2226, "Agaliarept", 225, Earlier),
        new(2227, "Agaliarept", 225, Earlier),
        new(2228, "Agaliarept", 225, Last),
        new(2137, "Echidna Queen", 228, Last),
        new(2144, "Cthulhu", 230, Last),
        new(2154, "Dimensional Eroder", 235, Last),
        new(2157, "Star Eater", 240, Earlier),
        new(2158, "Star Eater", 240, Last),
        new(2176, "Black Alice", 245, Last),
        new(2222, "Idea Lukas", 250, Last),
        new(2185, "EX Sonya", 255, Last),
        new(2187, "Koron", 260, Earlier),
        new(2188, "Koron", 260, Last),
        new(2211, "Goddess, Demon and Fiend", 275, Last),
        new(2212, "Goddess, Demon and Fiend", 275, Last),
        new(2213, "Goddess, Demon and Fiend", 275, Last),
        new(2214, "World Breaker and Judgement", 285, Earlier),
        new(2215, "World Breaker and Judgement", 285, Last),
        new(2216, "Deus Ex Machina", 300, Last),
        new(2217, "Chaos", null, Earlier),
        new(2218, "Chaos", null, Earlier),
        new(2219, "Chaos", null, Last),
    ];

    /// <summary>
    /// The one-time bosses outside the story that count as raid bosses, by troop: each its own fight
    /// of one phase under its name, without a cap, with its tier. The Megid Pandoras share one troop
    /// over several maps, so they stay out.
    /// </summary>
    private static readonly FrozenDictionary<int, (string Name, int Tier)> OptionalBosses = new Dictionary<int, (string Name, int Tier)>
    {
        [2549] = ("Fourth Law", 1),
        [3338] = ("Null Lilith", 1),
        [2923] = ("Fifth Law - Nirvana", 1),
        [3127] = ("Void Image of Paradise", 1),
        [2410] = ("Chaos Maria", 1),
        [2922] = ("Fifth Law - Fallen Angel", 1),
    }.ToFrozenDictionary();

    /// <summary>
    /// Maps where the story fights a boss troop before the fight that defeats it, by troop: Carmilla
    /// and Elizabeth withdraw from the Sabasa Attack, where the troop counts as an earlier phase.
    /// </summary>
    private static readonly FrozenDictionary<int, int> Skirmishes = new Dictionary<int, int> { [812] = 723, [813] = 723 }.ToFrozenDictionary();

    /// <summary>
    /// What each tier changes, tier 0 the strongest: the factor per stat of the game's, applied after
    /// the game's own difficulty; a stat a tier leaves out stays as the game has it.
    /// </summary>
    private static readonly FrozenDictionary<int, FrozenDictionary<string, double>> TierFactors = new Dictionary<int, FrozenDictionary<string, double>>
    {
        [0] = Factors(50, 5.0),
        [1] = Factors(45, 4.33),
        [2] = Factors(40, 3.67),
        [3] = Factors(35, 3.0),
        [4] = Factors(30, 2.33),
        [5] = Factors(25, 1.67),
        [6] = Factors(20),
        [7] = Factors(15),
        [8] = Factors(10),
        [9] = Factors(5),
    }.ToFrozenDictionary();

    /// <summary>
    /// The story's sections in story order, each with the troop it starts at in <see cref="Story"/>'s
    /// order; the ids interleave on the Chaos route, so the order counts.
    /// </summary>
    private static readonly (string Name, int Troop)[] SectionStarts =
        [("Part 1", 26), ("Part 2", 588), ("Part 3", 1451), ("Angelic Dominion", 1517), ("Monster Realm", 1745), ("Chaos route", 1959)];

    /// <summary>
    /// The story's bosses of each tier, by their milestone's name, see <see cref="MilestoneKey"/>.
    /// </summary>
    internal static readonly Dictionary<int, string[]> TierBosses = new()
    {
        [0] = ["Chaos"],
        [1] = ["Cosmos (cap 180)", "No Life King", "Angolmois (cap 190)", "Hiruko, Kanon and Kanade", "Baal Zebub", "Seven Deadly Sins vessels", "Greedy, Envious and Slothful Eva", "Seven Deadly Sins", "The All-Knowing", "Agaliarept", "Echidna Queen", "Cthulhu", "Dimensional Eroder", "Star Eater", "Black Alice (cap 245)", "Idea Lukas", "EX Sonya", "Koron", "Goddess, Demon and Fiend", "World Breaker and Judgement", "Deus Ex Machina"],
        [2] = ["Kagetsumugi and her dolls (cap 125)", "Angolmois (cap 130)", "Greedy Papi, Gob, Teeny and Vanilla", "Gabriela and Kanon", "Uriela", "Kanade (cap 140)", "Hiruko (cap 140)", "Magatsu-Omikami", "Apiro Lagos", "Zion and Laplace", "Sigrdrifa", "Metatronne and Sandalphone, then Singularity", "Sisel, EX-Kyubi, Frere and Bloody Dragon", "Saja (cap 168)", "World Drown"],
        [3] = ["Ilias", "Chaos Ilias", "Alipheese", "Chaos Alipheese"],
        [4] = ["Sonya Chaos", "Heaven's Gate", "Gabriela", "Uriela, Sabiriel and Fernandez", "Sariela", "Laplace", "Metatronne and Sandalphone", "Zion (three fights)", "Cosmos (cap 90)", "Aži Dahāka", "Marcellus and Black Alice", "Doppel Lukas and Lucifina", "Micaela", "Queen Eva", "Malboro Girl, then Kanon", "Kanade (cap 75)", "Tamamo (cap 80)", "Tamamo (cap 83)", "Minagi and Alipheese the 10th", "Kagetsumugi and her dolls (cap 90)", "Hiruko (cap 95)", "Kagetsumugi and Magatsu-Karura, then Black Alice", "Saja (cap 105)"],
        [5] = ["Sphinx", "Adramelech", "Black Dahlia, Black Mamba and Black Rose (cap 55)", "Black Alice (cap 65)", "Eden", "Sonya Mazda", "Sonya Mainyu", "Garuda", "Erubetie (cap 60)", "Black Dahlia, Black Mamba and Black Rose (cap 60)", "Tamamo (cap 61)", "Erubetie (cap 62)", "Granberia", "Great Decision"],
        [6] = ["Gnosis", "Zion", "Queen Fairy", "Queen Elf", "Queen Mermaid", "Spider Princess", "Queen Vampire"],
        [7] = ["Morrigan", "Sylph", "Astaroth", "Gnome", "Alma Elma, then Granberia", "Tezcatlipoca", "Undine", "Queen Ant", "Lilith", "Salamander", "Queen Alraune, then Aži Dahāka", "Carmilla", "Elizabeth"],
        [8] = ["Chrome and Frederica", "Sara", "Mephisto", "La Croix's zombies"],
        [9] = ["Four bandits", "Queen Harpy", "Bonnie and Ashel"],
    };

    /// <summary>
    /// The title above a raid boss's name on its HP bar, by the group the game's enemy library names
    /// it in, with its bosses' names; a boss outside them reads as a raid boss of its tier.
    /// </summary>
    internal static readonly Dictionary<string, string[]> TitleBosses = new()
    {
        ["Heavenly Knight"] = ["Alma Elma, then Granberia", "Tamamo (cap 61)", "Erubetie (cap 62)", "Granberia"],
        ["Archangel"] = ["Gabriela", "Uriela, Sabiriel and Fernandez", "Sariela", "Metatronne and Sandalphone", "Zion (three fights)"],
        ["Six Ancestors"] = ["Malboro Girl, then Kanon", "Kanade (cap 75)", "Tamamo (cap 80)", "Tamamo (cap 83)", "Minagi and Alipheese the 10th", "Hiruko (cap 95)", "Saja (cap 105)", "Hiruko, Kanon and Kanade"],
        ["Apostle of Chaos"] = ["Apiro Lagos", "Idea Lukas", "EX Sonya"],
        ["Phenomenon of Ruin"] = ["Angolmois (cap 130)", "Magatsu-Omikami", "Metatronne and Sandalphone, then Singularity", "World Drown", "Angolmois (cap 190)", "Baal Zebub", "Seven Deadly Sins", "Dimensional Eroder"],
        ["Chaos' Phantom"] = ["Fourth Law", "Null Lilith", "Fifth Law - Nirvana", "Void Image of Paradise", "Chaos Maria", "Fifth Law - Fallen Angel"],
    };

    /// <summary>
    /// The fights a milestone lets the player take in any order, by troop: each has a pool of its
    /// own under its name, while the milestone is beaten only once all are.
    /// </summary>
    private static readonly FrozenDictionary<int, string> Fights = new Dictionary<int, string>
    {
        [2016] = "Sisel",
        [2017] = "EX-Kyubi",
        [2018] = "Frere",
        [2019] = "Bloody Dragon",
        [2095] = "Envious Lily",
        [2096] = "Wrathful Cow Demon Queen",
        [2097] = "Gluttonous Cassandra",
        [2099] = "Lustful Witch",
        [2102] = "Prideful Fatima",
        [2211] = "Fiend",
        [2212] = "Goddess",
        [2213] = "Demon",
    }.ToFrozenDictionary();

    /// <summary>
    /// Last phases that fight no pool, by troop, with why: their events set the route for the whole world.
    /// </summary>
    private static readonly FrozenDictionary<int, string> UnpooledFights = new Dictionary<int, string>
    {
        [1507] = "the Great Decision sets the world's route",
        [1509] = "the Great Decision sets the world's route",
    }.ToFrozenDictionary();

    /// <summary>
    /// What tells each milestone beaten: the story's own markers, written after its last fight; see
    /// <see cref="BeatenMarker"/> for the form.
    /// </summary>
    private static readonly BeatenMarker[] Markers =
    [
        new("Four bandits", 10, "v{area_progress.0}>=8"),
        new("Queen Harpy", 15, "v{area_progress.1}>=4"),
        new("Morrigan", 18, "v{area_progress.2}>=6"),
        new("Chrome and Frederica", 20, "v1023>=2"),
        new("Sylph", 20, "v{main_progress}>=17"),
        new("Sphinx", 20, "s2090"),
        new("Sara", 20, "v1028>=6"),
        new("Astaroth", 20, "v1028>=7"),
        new("Gnome", 20, "v{main_progress}>=18"),
        new("Adramelech", 25, "v{area_progress.4}>=7"),
        new("Bonnie and Ashel", 25, "s7001"),
        new("Alma Elma, then Granberia", 30, "v{area_progress.5}>=6"),
        new("Mephisto", 30, "s2268"),
        new("Tezcatlipoca", 30, "v1056>=4"),
        new("Gnosis", 30, "s7005"),
        new("Zion", 30, "s7006"),
        new("Undine", 30, "v{main_progress}>=25"),
        new("Queen Ant", 30, "s7011"),
        new("Lilith", 35, "v{area_progress.6}>=13"),
        new("Salamander", 40, "v{main_progress}>=28"),
        new("Queen Fairy", 40, "s2161"),
        new("Queen Elf", 43, "v1070>=3"),
        new("Queen Alraune, then Aži Dahāka", 43, "v1074>=2"),
        new("Queen Mermaid", 45, "v1071>=3"),
        new("Spider Princess", 47, "v1072>=3"),
        new("Carmilla", 47, "s2252"),
        new("Elizabeth", 47, "s2253"),
        new("Queen Vampire", 50, "v1073>=3"),
        new("La Croix's zombies", 50, "s2266"),
        new("Black Dahlia, Black Mamba and Black Rose", 55, "v1069>=9"),
        new("Black Alice", 65, "s2261"),
        new("Eden", 55, "s7015"),
        new("Sonya Mazda", 55, "s7009"),
        new("Sonya Mainyu", 55, "s7010"),
        new("Sonya Chaos", 55, "v{main_progress}>=34"),
        new("Garuda", 60, "v{main_progress}>=37"),
        new("Erubetie", 60, "v{area_progress.9}>=3"),
        new("Black Dahlia, Black Mamba and Black Rose", 60, "s2435"),
        new("Tamamo", 61, "s{castle_bosses.0}"),
        new("Erubetie", 62, "s{castle_bosses.1}"),
        new("Granberia", 63, "s{castle_bosses.2}"),
        new("Great Decision", 65, "v{route_variables.0}>=1|v{route_variables.1}>=1"),
        new("Heaven's Gate", 67, "v{route_variables.0}>=4"),
        new("Gabriela", 70, "v{route_variables.0}>=18"),
        new("Uriela, Sabiriel and Fernandez", 75, "v{route_variables.0}>=30"),
        new("Sariela", 78, "v{route_variables.0}>=30"),
        new("Laplace", 80, "v{route_variables.0}>=38"),
        new("Metatronne and Sandalphone", 83, "v{route_variables.0}>=43"),
        new("Zion (three fights)", 85, "v1173>=8"),
        new("Cosmos", 90, "v1151>=6"),
        new("Aži Dahāka", 95, "v{route_variables.0}>=58"),
        new("Marcellus and Black Alice", 95, "v{route_variables.0}>=62"),
        new("Doppel Lukas and Lucifina", 100, "v{route_variables.0}>=67|v{route_variables.1}>=71"),
        new("Micaela", 105, "v{route_variables.0}>=73"),
        new("Ilias", 115, "s{clear_switches.0}"),
        new("Chaos Ilias", 120, "s{clear_switches.0}"),
        new("Queen Eva", 67, "v{route_variables.1}>=8"),
        new("Malboro Girl, then Kanon", 70, "s2594&v{route_variables.1}>=25"),
        new("Kanade", 75, "v{route_variables.1}>=33"),
        new("Tamamo", 80, "v{route_variables.1}>=34"),
        new("Tamamo", 83, "v{route_variables.1}>=36"),
        new("Minagi and Alipheese the 10th", 85, "v1169>=23"),
        new("Kagetsumugi and her dolls", 90, "v{route_variables.1}>=47"),
        new("Hiruko", 95, "v{route_variables.1}>=60"),
        new("Kagetsumugi and Magatsu-Karura, then Black Alice", 95, "v{route_variables.1}>=63"),
        new("Saja", 105, "v{route_variables.1}>=81"),
        new("Alipheese", 115, "s{clear_switches.1}"),
        new("Chaos Alipheese", 120, "s{clear_switches.1}"),
        new("Kagetsumugi and her dolls", 125, "v{route_variables.2}>=4"),
        new("Angolmois", 130, "v{route_variables.2}>=18"),
        new("Greedy Papi, Gob, Teeny and Vanilla", 135, "v1319>=7"),
        new("Gabriela and Kanon", 135, "v1301>=8"),
        new("Uriela", 135, "v1302>=5"),
        new("Kanade", 140, "v1302>=7"),
        new("Hiruko", 140, "v1304>=5"),
        new("Magatsu-Omikami", 145, "v1307>=3"),
        new("Apiro Lagos", 147, "v1305>=6"),
        new("Zion and Laplace", 151, "v1308>=8"),
        new("Sigrdrifa", 153, "v1308>=11"),
        new("Metatronne and Sandalphone, then Singularity", 155, "v1308>=13"),
        new("Sisel, EX-Kyubi, Frere and Bloody Dragon", 160, "s3030&s3031&s3032&s3033"),
        new("Saja", 168, "v1312>=3"),
        new("World Drown", 175, "v1313>=5"),
        new("Cosmos", 180, "v1315>=6"),
        new("No Life King", 185, "v1316>=11"),
        new("Angolmois", 190, "v1314>=3"),
        new("Hiruko, Kanon and Kanade", 195, "v1317>=3"),
        new("Baal Zebub", 203, "v1318>=10"),
        new("Seven Deadly Sins vessels", 210, "v1328>=6&v1331>=5&v1329>=4&v1332>=5&v1326>=4"),
        new("Greedy, Envious and Slothful Eva", 213, "v1325>=11"),
        new("Seven Deadly Sins", 215, "v1325>=12"),
        new("The All-Knowing", 220, "v1334>=4"),
        new("Agaliarept", 225, "v1373>=13"),
        new("Echidna Queen", 228, "v1335>=5"),
        new("Cthulhu", 230, "v1336>=5"),
        new("Dimensional Eroder", 235, "v1338>=4"),
        new("Star Eater", 240, "v1339>=5"),
        new("Black Alice", 245, "v1342>=5"),
        new("Idea Lukas", 250, "v1342>=5"),
        new("EX Sonya", 255, "v1343>=3"),
        new("Koron", 260, "v1345>=5"),
        new("Goddess, Demon and Fiend", 275, "s3079&s3078&s3077"),
        new("World Breaker and Judgement", 285, "s3080&s3081"),
        new("Deus Ex Machina", 300, "s{clear_switches.2}"),
        new("Chaos", null, "s{clear_switches.2}"),
    ];

    /// <summary>
    /// The one-time bosses in the order the overview lists them.
    /// </summary>
    private static readonly int[] OptionalOrder = [2549, 3338, 2923, 3127, 2410, 2922];

    /// <summary>
    /// The bosses of <see cref="Story"/> by troop.
    /// </summary>
    private static readonly FrozenDictionary<int, RaidBoss> ByTroop = Story.ToFrozenDictionary(boss => boss.Troop);

    /// <summary>
    /// The tier of each boss's name.
    /// </summary>
    private static readonly FrozenDictionary<string, int> TierOfName =
        TierBosses.SelectMany(tier => tier.Value.Select(name => (Name: name, Tier: tier.Key))).Concat(OptionalBosses.Values)
            .ToFrozenDictionary(pair => pair.Name, pair => pair.Tier, StringComparer.Ordinal);

    /// <summary>
    /// The title of each boss's name.
    /// </summary>
    private static readonly FrozenDictionary<string, string> TitleOfName =
        TitleBosses.SelectMany(title => title.Value.Select(name => (Name: name, Title: title.Key))).ToFrozenDictionary(pair => pair.Name, pair => pair.Title, StringComparer.Ordinal);

    /// <summary>
    /// The milestones whose name several caps share, which a boss's name then carries its cap in.
    /// </summary>
    private static readonly FrozenSet<string> SharedNames =
        Story.GroupBy(boss => boss.Milestone).Where(group => group.Select(boss => boss.Cap).Distinct().Count() > 1).Select(group => group.Key).ToFrozenSet(StringComparer.Ordinal);

    /// <summary>
    /// The beaten marker of each milestone and cap.
    /// </summary>
    private static readonly Dictionary<(string Milestone, int? Cap), BeatenMarker> MarkerOf = Markers.ToDictionary(marker => (marker.Milestone, marker.Cap));

    /// <summary>
    /// Gets every boss troop: the story's in story order, then the one-time bosses.
    /// </summary>
    public static IReadOnlyList<int> Troops { get; } = [.. Story.Select(boss => boss.Troop), .. OptionalOrder];

    /// <summary>
    /// Gets the tiers, each with the factors it gives the stats it changes.
    /// </summary>
    public static IReadOnlyDictionary<int, FrozenDictionary<string, double>> Tiers => TierFactors;

    /// <summary>
    /// Gets the stats any tier changes besides max HP.
    /// </summary>
    public static IReadOnlyList<string> TierStats { get; } = [.. TierFactors.Values.SelectMany(factors => factors.Keys).Distinct().Where(stat => stat != "mhp").Order(StringComparer.Ordinal)];

    /// <summary>
    /// Gets the titles a raid boss's bar may carry besides its tier's.
    /// </summary>
    public static IReadOnlyList<string> Titles { get; } = [.. TitleBosses.Keys];

    /// <summary>
    /// Gets the story's sections in story order with their bosses' names, each once, in the order
    /// the story meets them; the one-time bosses last under <see cref="OptionalSection"/>.
    /// </summary>
    public static IReadOnlyList<(string Name, IReadOnlyList<string> Bosses)> Sections { get; } = SectionsOf();

    /// <summary>
    /// Gets the switches the rules read: the sides' and those of the beaten markers.
    /// </summary>
    public static IReadOnlyList<int> ReadSwitches { get; } =
        [.. Story.Where(boss => boss.LastSwitch > 0).Select(boss => boss.LastSwitch).Concat(Markers.SelectMany(marker => marker.Switches)).Distinct().Order()];

    /// <summary>
    /// Gets the variables the rules read: those of the beaten markers.
    /// </summary>
    public static IReadOnlyList<int> ReadVariables { get; } = [.. Markers.SelectMany(marker => marker.Variables).Distinct().Order()];

    /// <summary>
    /// Gets the beaten markers.
    /// </summary>
    public static IReadOnlyList<BeatenMarker> BeatenMarkers => Markers;

    /// <summary>
    /// Finds a boss troop of the story or a one-time boss.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <returns>The boss, null for a troop that is none.</returns>
    public static RaidBoss? At(int troop) =>
        ByTroop.TryGetValue(troop, out RaidBoss? boss) ? boss : OptionalBosses.TryGetValue(troop, out var optional) ? new RaidBoss(troop, optional.Name, null, Last) : null;

    /// <summary>
    /// Tells whether a troop is a boss of the story or a one-time boss.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsBoss(int troop) => ByTroop.ContainsKey(troop) || OptionalBosses.ContainsKey(troop);

    /// <summary>
    /// Finds the map where the story fights a troop before the fight that defeats it.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <returns>The map, null for none.</returns>
    public static int? SkirmishMap(int troop) => Skirmishes.TryGetValue(troop, out int map) ? map : null;

    /// <summary>
    /// Finds the name of a boss troop's milestone, with its cap where several milestones share the
    /// name, such as "Tamamo (cap 61)"; a one-time boss's own name.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <returns>The name, null for a troop that is no boss.</returns>
    public static string? MilestoneKey(int troop) => At(troop) is { } boss ? NameOf(boss) : null;

    /// <summary>
    /// Finds the tier of a boss troop.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <returns>The tier, null for a troop that is no boss.</returns>
    public static int? Tier(int troop) => OptionalBosses.TryGetValue(troop, out var optional) ? optional.Tier : MilestoneKey(troop) is { } name ? TierOf(name) : null;

    /// <summary>
    /// Finds the tier of a boss by its name: its milestone's or its own as a one-time boss.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>The tier, null for a name the table lacks.</returns>
    public static int? TierOf(string name) => TierOfName.TryGetValue(name, out int tier) ? tier : null;

    /// <summary>
    /// Finds the title above a boss's name on its HP bar.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <returns>The title, such as "Archangel" or "Tier 6 Raid Boss"; null for a troop that is no boss.</returns>
    public static string? Title(int troop) =>
        MilestoneKey(troop) is not { } name ? null : TitleOfName.TryGetValue(name, out string? title) ? title : $"Tier {Tier(troop)} Raid Boss";

    /// <summary>
    /// Finds the section a boss belongs to.
    /// </summary>
    /// <param name="name">Its name, see <see cref="MilestoneKey"/>.</param>
    /// <returns>The section's name, null for a boss the table lacks.</returns>
    public static string? SectionOf(string name) => Sections.FirstOrDefault(section => section.Bosses.Contains(name)).Name;

    /// <summary>
    /// Finds the factor a boss troop's tier gives one of its enemies' stats.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="stat">The stat, such as "mhp".</param>
    /// <returns>The factor, 1 for a stat the tier leaves or a troop that is no boss.</returns>
    public static double Factor(int troop, string stat) =>
        Tier(troop) is { } tier && TierFactors.TryGetValue(tier, out var factors) && factors.TryGetValue(stat, out double factor) ? factor : 1;

    /// <summary>
    /// Finds a troop's pool key: the fight's own name for a fight a milestone lets the player take in
    /// any order, else its milestone's name.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <returns>The key, null for a troop that is no boss or a key the relay refuses.</returns>
    public static string? KeyOf(int troop)
    {
        string? key = Fights.TryGetValue(troop, out string? fight) ? fight : MilestoneKey(troop);
        return key is { Length: > 0 and <= MaxKeyLength } && key.Trim() == key && !key.Contains('#', StringComparison.Ordinal) ? key : null;
    }

    /// <summary>
    /// Finds the pools' keys of a boss's own enemies: the boss's key for one enemy, else one per
    /// enemy, the key with its place in the troop, such as "Metatronne and Sandalphone#1".
    /// </summary>
    /// <param name="key">The boss's key.</param>
    /// <param name="own">How many enemies the troop's setup makes.</param>
    /// <returns>The keys.</returns>
    public static IReadOnlyList<string> MemberKeys(string key, int own) => own <= 1 ? [key] : [.. Enumerable.Range(0, own).Select(index => $"{key}#{index}")];

    /// <summary>
    /// Finds the boss's key of a pool's key, without the enemy's place in the troop.
    /// </summary>
    /// <param name="key">The pool's key.</param>
    /// <returns>The boss's key.</returns>
    public static string BossKeyOf(string key)
    {
        int mark = key.LastIndexOf('#');
        return mark >= 0 && mark < key.Length - 1 && key.AsSpan(mark + 1).IndexOfAnyExceptInRange('0', '9') < 0 ? key[..mark] : key;
    }

    /// <summary>
    /// Finds the troop of a boss's key: the first last phase that has it.
    /// </summary>
    /// <param name="key">The boss's key.</param>
    /// <returns>The troop, null for none.</returns>
    public static int? TroopOfKey(string key)
    {
        foreach (int troop in Troops)
        {
            if (At(troop)!.LastSwitch != Earlier && KeyOf(troop) == key)
            {
                return troop;
            }
        }

        return null;
    }

    /// <summary>
    /// Tells why a last phase fights no pool, as its events set the route for the whole world.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <returns>Why, null for a troop that may.</returns>
    public static string? Unpooled(int troop) => UnpooledFights.TryGetValue(troop, out string? why) ? why : null;

    /// <summary>
    /// Finds the beaten marker of a boss's milestone.
    /// </summary>
    /// <param name="boss">The boss.</param>
    /// <returns>The marker, null for a milestone without one.</returns>
    public static BeatenMarker? MarkerFor(RaidBoss boss) => MarkerOf.TryGetValue((boss.Milestone, boss.Cap), out BeatenMarker? marker) ? marker : null;

    /// <summary>
    /// Names a boss, with its cap where several milestones share its name.
    /// </summary>
    /// <param name="boss">The boss.</param>
    /// <returns>The name.</returns>
    private static string NameOf(RaidBoss boss) => SharedNames.Contains(boss.Milestone) ? $"{boss.Milestone} (cap {boss.Cap})" : boss.Milestone;

    /// <summary>
    /// Lists the story's sections, see <see cref="Sections"/>.
    /// </summary>
    /// <returns>The sections.</returns>
    private static List<(string Name, IReadOnlyList<string> Bosses)> SectionsOf()
    {
        var sections = new List<(string Name, List<string> Bosses)>();
        foreach (RaidBoss boss in Story)
        {
            int start = Array.FindIndex(SectionStarts, each => each.Troop == boss.Troop);
            if (start >= 0)
            {
                sections.Add((SectionStarts[start].Name, []));
            }

            string name = NameOf(boss);
            if (!sections[^1].Bosses.Contains(name))
            {
                sections[^1].Bosses.Add(name);
            }
        }

        sections.Add((OptionalSection, [.. OptionalOrder.Select(troop => OptionalBosses[troop].Name)]));
        return [.. sections.Select(section => (section.Name, (IReadOnlyList<string>)section.Bosses))];
    }

    /// <summary>
    /// Makes the factors of a tier.
    /// </summary>
    /// <param name="hp">The factor of max HP.</param>
    /// <param name="defense">The factor of defense and magic defense, 1 for none.</param>
    /// <returns>The factors by stat.</returns>
    private static FrozenDictionary<string, double> Factors(double hp, double defense = 1) =>
        (defense == 1 ? new Dictionary<string, double> { ["mhp"] = hp } : new Dictionary<string, double> { ["mhp"] = hp, ["def"] = defense, ["mdf"] = defense }).ToFrozenDictionary();
}
