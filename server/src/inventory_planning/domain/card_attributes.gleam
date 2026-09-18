import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/result
import gleam/string
import shared/domain/card_key.{type CardKey}
import shared/domain/color_identity.{type ColorIdentity}
import shared/domain/finish.{type Finish}
import shared/domain/language.{type Language}
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

// Priority list over the type line: the first type present wins.
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

pub fn card_type_from_type_line(type_line: String) -> CardType {
  let lower = string.lowercase(type_line)
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

// A collection row joined with whatever the catalog knew about it. oracle_id,
// rarity, color_identity, and card_type are optional because a collection row
// may reference a printing the catalog doesn't (yet) carry; such a card fails
// every attribute predicate and cascades through to bulk. finish/language come
// from the collection itself (ADR 0010), so they're never absent.
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

// Total order among kinds of copy of one printing: nonfoil < foil < etched.
// Inventory Planning's own policy (ADR 0010), changed only through rule order.
pub fn finish_rank(value: Finish) -> Int {
  case value {
    finish.Nonfoil -> 0
    finish.Foil -> 1
    finish.Etched -> 2
  }
}

// English before every other language, then the rest by Scryfall code. Also
// Inventory Planning's own tiebreak (ADR 0010) — not a claim that a card's
// "true" language is English, only a default sort preference.
pub fn compare_language_en_first(a: Language, b: Language) -> Order {
  case a, b {
    language.En, language.En -> order.Eq
    language.En, _ -> order.Lt
    _, language.En -> order.Gt
    _, _ -> string.compare(language.to_string(a), language.to_string(b))
  }
}
