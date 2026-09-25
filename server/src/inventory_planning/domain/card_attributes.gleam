import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/result
import gleam/string
import shared/domain/card_key.{type CardKey}
import shared/domain/color_identity.{type ColorIdentity}
import shared/domain/finish.{type Finish}
import shared/domain/language.{type Language}
import shared/domain/mana_value.{type ManaValue}
import shared/domain/oracle_id.{type OracleId}
import shared/domain/rarity.{type Rarity}
import shared/domain/release_date.{type ReleaseDate}

// Planning's *policy* over the shared card facts (ADR 0008): the rarity total
// order, the DSL spellings, the color display order, and the type-line
// reduction. The representations themselves live in shared/domain.

// Total order: common < uncommon < special < bonus < rare < mythic. special and
// bonus sit *below* rare deliberately, so `rarity >= rare` excludes them; the
// escape hatch is `rarity in (...)`.
pub fn rarity_rank(value: Rarity) -> Int {
  case value {
    rarity.Common -> 0
    rarity.Uncommon -> 1
    rarity.Special -> 2
    rarity.Bonus -> 3
    rarity.Rare -> 4
    rarity.Mythic -> 5
  }
}

pub fn rarity_at_least(value: Rarity, threshold: Rarity) -> Bool {
  rarity_rank(value) >= rarity_rank(threshold)
}

// DSL spelling of a rarity: user input, so trimmed and case-insensitive.
pub fn parse_rarity(raw: String) -> Result(Rarity, Nil) {
  rarity.parse(string.lowercase(string.trim(raw)))
}

// DSL spelling of a finish: user input, so trimmed and case-insensitive.
pub fn parse_finish(raw: String) -> Result(Finish, Nil) {
  finish.from_user_input(raw) |> result.replace_error(Nil)
}

// DSL spelling of a language: user input, so trimmed and case-insensitive
// Scryfall lang codes ("en", "de", "zhs", ...).
pub fn parse_language(raw: String) -> Result(Language, Nil) {
  language.from_user_input(raw) |> result.replace_error(Nil)
}

// DSL spelling of a color identity: the joined-letter form ("WU") plus the
// words "colorless"/"c". Letters in any order; the result is canonical.
pub fn parse_color_identity(raw: String) -> Result(ColorIdentity, Nil) {
  case string.lowercase(string.trim(raw)) {
    "colorless" | "c" -> Ok(color_identity.colorless())
    _ -> color_identity.parse(raw)
  }
}

// DSL token that round-trips through parse_color_identity ("WU" / "colorless").
pub fn color_identity_token(identity: ColorIdentity) -> String {
  case color_identity.is_colorless(identity) {
    True -> "colorless"
    False -> color_identity.letters(identity)
  }
}

// Human-facing label for location templates ("WU" / "Colorless").
pub fn color_identity_label(identity: ColorIdentity) -> String {
  case color_identity.is_colorless(identity) {
    True -> "Colorless"
    False -> color_identity.letters(identity)
  }
}

// The 26 multicolor identities in the order WOTC prints them on the cards
// themselves: allied pairs, enemy pairs, shards, wedges, four-color (each
// "missing one color"), five-color. Spelled in canonical WUBRG letter order to
// match `color_identity.letters`, so a cycle that starts off-W here reads
// shifted (e.g. Naya's "RGW" is listed as "WRG").
const multicolor_order = [
  "WU", "UB", "BR", "RG", "WG", "WB", "UR", "BG", "WR", "UG", "WUB", "UBR",
  "BRG", "WRG", "WUG", "WBG", "WUR", "UBG", "WBR", "URG", "WUBR", "UBRG", "WBRG",
  "WURG", "WUBG", "WUBRG",
]

// Position of a 2..5-color identity within `multicolor_order`. Every canonical
// letter spelling of such an identity is in the table by construction; the
// fallback (past every real entry) only matters if `Color` grows a case
// without this table being extended to match.
fn multicolor_rank(identity: ColorIdentity) -> Int {
  let letters = color_identity.letters(identity)
  multicolor_order
  |> list.index_map(fn(item, index) { #(item, index) })
  |> list.key_find(letters)
  |> result.unwrap(list.length(multicolor_order))
}

// Total order over the 32 color identities: mono colors in WUBRG order, then
// multicolor in WOTC's printed order (allied < enemy < shards < wedges <
// four-color < five-color), then colorless last. Planning's display policy
// over a shared representation (ADR 0008) — color identity has no intrinsic
// order of its own.
pub fn color_identity_rank(identity: ColorIdentity) -> Int {
  case color_identity.colors(identity) {
    [] -> 31
    [color] -> color_identity.color_rank(color)
    _ -> 5 + multicolor_rank(identity)
  }
}

// Priority list over the type line's front face: the first type present
// wins.
pub type CardType {
  Land
  Creature
  Artifact
  Enchantment
  Planeswalker
  Battle
  Instant
  Sorcery
  Other
}

const type_priority = [
  #("land", Land),
  #("creature", Creature),
  #("artifact", Artifact),
  #("enchantment", Enchantment),
  #("planeswalker", Planeswalker),
  #("battle", Battle),
  #("instant", Instant),
  #("sorcery", Sorcery),
]

// A double-faced card has only its front face's characteristics outside the
// stack and battlefield (CR 712.8a); a binder is outside the game, so
// placement reads the front face only (ADR 0018). Split cards' two halves
// almost always share a type, so reading the front half is an accepted
// approximation there too. `layout` (see is_token_layout below) could now
// tell split and double-faced cards apart, but wiring that fix through
// card_type_from_type_line is a follow-up, not part of #135.
fn front_face(type_line: String) -> String {
  case string.split_once(type_line, " // ") {
    Ok(#(front, _back)) -> front
    Error(Nil) -> type_line
  }
}

pub fn card_type_from_type_line(type_line: String) -> CardType {
  let lower = string.lowercase(front_face(type_line))
  type_priority
  |> list.find_map(fn(pair) {
    case string.contains(lower, pair.0) {
      True -> Ok(pair.1)
      False -> Error(Nil)
    }
  })
  |> result.unwrap(Other)
}

pub fn parse_card_type(raw: String) -> Result(CardType, Nil) {
  case string.lowercase(string.trim(raw)) {
    "land" -> Ok(Land)
    "creature" -> Ok(Creature)
    "artifact" -> Ok(Artifact)
    "enchantment" -> Ok(Enchantment)
    "planeswalker" -> Ok(Planeswalker)
    "battle" -> Ok(Battle)
    "instant" -> Ok(Instant)
    "sorcery" -> Ok(Sorcery)
    "other" -> Ok(Other)
    _ -> Error(Nil)
  }
}

pub fn card_type_to_string(card_type: CardType) -> String {
  case card_type {
    Land -> "land"
    Creature -> "creature"
    Artifact -> "artifact"
    Enchantment -> "enchantment"
    Planeswalker -> "planeswalker"
    Battle -> "battle"
    Instant -> "instant"
    Sorcery -> "sorcery"
    Other -> "other"
  }
}

pub fn card_type_rank(card_type: CardType) -> Int {
  case card_type {
    Land -> 0
    Creature -> 1
    Artifact -> 2
    Enchantment -> 3
    Planeswalker -> 4
    Battle -> 5
    Instant -> 6
    Sorcery -> 7
    Other -> 8
  }
}

// CR 205.4a's closed supertype set. A card can carry more than one
// ("Basic Snow Land — Plains"), unlike CardType's single reduced value.
pub type Supertype {
  Legendary
  Basic
  Snow
  World
  Ongoing
}

pub fn parse_supertype(raw: String) -> Result(Supertype, Nil) {
  case string.lowercase(string.trim(raw)) {
    "legendary" -> Ok(Legendary)
    "basic" -> Ok(Basic)
    "snow" -> Ok(Snow)
    "world" -> Ok(World)
    "ongoing" -> Ok(Ongoing)
    _ -> Error(Nil)
  }
}

pub fn supertype_to_string(value: Supertype) -> String {
  case value {
    Legendary -> "legendary"
    Basic -> "basic"
    Snow -> "snow"
    World -> "world"
    Ongoing -> "ongoing"
  }
}

// Supertypes print left of card types, so they're a prefix of the front
// face's words (ADR 0018) — a positional walk, not the substring test
// card_type_from_type_line uses. Stops at the first word that isn't a
// supertype, so a subtype that happens to share a supertype's spelling
// (after the em dash) is never reached.
pub fn supertypes_from_type_line(type_line: String) -> List(Supertype) {
  type_line
  |> front_face
  |> string.split(" ")
  |> supertype_prefix
}

fn supertype_prefix(words: List(String)) -> List(Supertype) {
  case words {
    [] -> []
    [word, ..rest] ->
      case parse_supertype(word) {
        Ok(supertype) -> [supertype, ..supertype_prefix(rest)]
        Error(Nil) -> []
      }
  }
}

// Which of Scryfall's `layout` values are tokens (#135): the two layouts
// Scryfall uses for actual token cards. Emblems, dungeons, and art-series
// cards ("Card // Token Creature — Elemental" is `art_series`) have their
// own distinct layout values and are deliberately not tokens — out of scope
// per the issue.
pub fn is_token_layout(layout: String) -> Bool {
  case layout {
    "token" | "double_faced_token" -> True
    _ -> False
  }
}

// DSL spelling of a boolean clause value (`token = yes` / `token = no`):
// user input, so trimmed and case-insensitive.
pub fn parse_yes_no(raw: String) -> Result(Bool, Nil) {
  case string.lowercase(string.trim(raw)) {
    "yes" -> Ok(True)
    "no" -> Ok(False)
    _ -> Error(Nil)
  }
}

pub fn yes_no_to_string(value: Bool) -> String {
  case value {
    True -> "yes"
    False -> "no"
  }
}

// Ordering policy for possibly-unknown release dates: unknown sorts first,
// treated as earliest (the pre-strong-typing '' behaviour).
pub fn compare_release_earliest_first(
  left: Option(ReleaseDate),
  right: Option(ReleaseDate),
) -> Order {
  case left, right {
    None, None -> order.Eq
    None, Some(_) -> order.Lt
    Some(_), None -> order.Gt
    Some(l), Some(r) -> release_date.compare(l, r)
  }
}

// Ordering policy for possibly-unknown mana value: unknown sorts last, like
// every other optional attribute below (color/type/rarity) — unlike
// released_at above, which deliberately puts unknown first. 0 (lands) is a
// real value, never conflated with "the catalog doesn't know".
pub fn compare_cmc_lowest_first(
  left: Option(ManaValue),
  right: Option(ManaValue),
) -> Order {
  case left, right {
    None, None -> order.Eq
    None, Some(_) -> order.Gt
    Some(_), None -> order.Lt
    Some(l), Some(r) -> mana_value.compare(l, r)
  }
}

// A collection row joined with whatever the catalog knew about it. oracle_id,
// rarity, color_identity, card_type, and supertypes are optional because a
// collection row may reference a printing the catalog doesn't (yet) carry;
// such a card fails every attribute predicate and cascades through to bulk.
// finish/language come from the collection itself (ADR 0010), so they're
// never absent. supertypes is `Some([])` for a known card with no
// supertypes — distinct from `None` (catalog doesn't know), since `!=`
// clauses must not treat the two the same (ADR 0017). is_token is the same
// catalog-gap shape: None when the catalog has no row or hasn't been
// reloaded since #135 added `layout` (NULL), Some(is_token_layout(...))
// once it has.
pub type PlannedCard {
  PlannedCard(
    key: CardKey,
    name: String,
    quantity: Int,
    finish: Finish,
    language: Language,
    released_at: Option(ReleaseDate),
    oracle_id: Option(OracleId),
    rarity: Option(Rarity),
    color_identity: Option(ColorIdentity),
    card_type: Option(CardType),
    supertypes: Option(List(Supertype)),
    cmc: Option(ManaValue),
    is_token: Option(Bool),
  )
}

// Canonical identity string for a printing (set_code/collector_number).
pub fn printing_key(card: PlannedCard) -> String {
  card_key.set_code_string(card.key)
  <> "/"
  <> card_key.collector_number_string(card.key)
}

// Canonical identity string for a kind of copy: the printing plus finish and
// language. The remaining-copies pool is keyed on this, one entry per kind of
// copy of a printing, distinct from `printing_key` which selectors still
// dedupe on (ADR 0010).
pub fn copy_key_string(card: PlannedCard) -> String {
  printing_key(card)
  <> "/"
  <> finish.to_string(card.finish)
  <> "/"
  <> language.to_string(card.language)
}

// A rank over finishes, ascending: nonfoil < foil < etched. Inventory Planning's
// own policy (ADR 0010). It is a rank, not a preference — the claim order reads
// it descending, so the etched copy is the one claimed (ADR 0013).
pub fn finish_rank(value: Finish) -> Int {
  case value {
    finish.Nonfoil -> 0
    finish.Foil -> 1
    finish.Etched -> 2
  }
}

// English before every other language, then the rest by Scryfall code. Inventory
// Planning's own policy and the first step of the claim order (ADR 0013) — not a
// claim that a card's "true" language is English, only a sort preference.
pub fn compare_language_en_first(a: Language, b: Language) -> Order {
  case a, b {
    language.En, language.En -> order.Eq
    language.En, _ -> order.Lt
    _, language.En -> order.Gt
    _, _ -> string.compare(language.to_string(a), language.to_string(b))
  }
}
