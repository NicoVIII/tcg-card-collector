import gleam/list
import gleam/option
import gleam/result
import gleam/string
import inventory_planning/domain/card_attributes.{
  type CardType, type PlannedCard, type Supertype,
}
import shared/domain/card_key
import shared/domain/color_identity.{type ColorIdentity}
import shared/domain/finish.{type Finish}
import shared/domain/language.{type Language}
import shared/domain/rarity.{type Rarity}

// A rule's match condition. No `or` and no nesting this milestone: a predicate
// is a conjunction of clauses joined by `and`.
pub type Predicate {
  SetCodeIn(set_codes: List(String))
  RarityAtLeast(rarity: Rarity)
  RarityIn(rarities: List(Rarity))
  ColorIdentityIs(color_identity: ColorIdentity)
  CardTypeIs(card_type: CardType)
  FinishIn(finishes: List(Finish))
  LanguageIn(languages: List(Language))
  SupertypeIn(supertypes: List(Supertype))
  SetCodeIsNot(set_code: String)
  ColorIdentityIsNot(color_identity: ColorIdentity)
  CardTypeIsNot(card_type: CardType)
  FinishIsNot(finish: Finish)
  LanguageIsNot(language: Language)
  SupertypeIsNot(supertype: Supertype)
  And(left: Predicate, right: Predicate)
}

pub type ParseError {
  EmptyPredicate
  EmptyClause
  MalformedClause(clause: String)
  UnknownAttribute(attribute: String)
  UnknownRarity(value: String)
  UnknownColorIdentity(value: String)
  UnknownCardType(value: String)
  UnknownFinish(value: String)
  UnknownLanguage(value: String)
  UnknownSupertype(value: String)
  EmptyList
}

// --- Lexing ---------------------------------------------------------------

type Token {
  Ident(String)
  LParen
  RParen
  Comma
  Eq
  NotEq
  Gte
}

fn lex(raw: String) -> Result(List(Token), ParseError) {
  lex_loop(string.to_graphemes(raw), "", [])
}

fn flush(pending: String, acc: List(Token)) -> List(Token) {
  case pending {
    "" -> acc
    _ -> [Ident(pending), ..acc]
  }
}

fn lex_loop(
  graphemes: List(String),
  pending: String,
  acc: List(Token),
) -> Result(List(Token), ParseError) {
  case graphemes {
    [] -> Ok(list.reverse(flush(pending, acc)))
    [g, ..rest] ->
      case g {
        " " | "\t" | "\n" | "\r" -> lex_loop(rest, "", flush(pending, acc))
        "(" -> lex_loop(rest, "", [LParen, ..flush(pending, acc)])
        ")" -> lex_loop(rest, "", [RParen, ..flush(pending, acc)])
        "," -> lex_loop(rest, "", [Comma, ..flush(pending, acc)])
        "=" -> lex_loop(rest, "", [Eq, ..flush(pending, acc)])
        ">" ->
          case rest {
            ["=", ..rest2] -> lex_loop(rest2, "", [Gte, ..flush(pending, acc)])
            _ -> Error(MalformedClause(">"))
          }
        "!" ->
          case rest {
            ["=", ..rest2] ->
              lex_loop(rest2, "", [NotEq, ..flush(pending, acc)])
            _ -> Error(MalformedClause("!"))
          }
        _ -> lex_loop(rest, pending <> g, acc)
      }
  }
}

// --- Parsing --------------------------------------------------------------

pub fn parse(raw: String) -> Result(Predicate, ParseError) {
  use tokens <- result.try(lex(raw))
  use <- guard_non_empty(tokens)
  use clauses <- result.try(split_clauses(tokens, [], []))
  use predicates <- result.try(list.try_map(clauses, parse_clause))
  case predicates {
    [] -> Error(EmptyPredicate)
    [first, ..rest] -> Ok(list.fold(rest, first, fn(acc, p) { And(acc, p) }))
  }
}

fn guard_non_empty(
  tokens: List(Token),
  continue: fn() -> Result(Predicate, ParseError),
) -> Result(Predicate, ParseError) {
  case tokens {
    [] -> Error(EmptyPredicate)
    _ -> continue()
  }
}

// Splits the token stream on `and` at paren depth 0.
fn split_clauses(
  tokens: List(Token),
  current: List(Token),
  acc: List(List(Token)),
) -> Result(List(List(Token)), ParseError) {
  case tokens {
    [] -> Ok(list.reverse([list.reverse(current), ..acc]))
    [Ident(word), ..rest] ->
      case string.lowercase(word), depth(current) {
        "and", 0 ->
          case current {
            [] -> Error(EmptyClause)
            _ -> split_clauses(rest, [], [list.reverse(current), ..acc])
          }
        _, _ -> split_clauses(rest, [Ident(word), ..current], acc)
      }
    [token, ..rest] -> split_clauses(rest, [token, ..current], acc)
  }
}

fn depth(tokens: List(Token)) -> Int {
  list.fold(tokens, 0, fn(d, t) {
    case t {
      LParen -> d + 1
      RParen -> d - 1
      _ -> d
    }
  })
}

fn parse_clause(tokens: List(Token)) -> Result(Predicate, ParseError) {
  case tokens {
    [Ident(attr), Eq, Ident(value)] -> parse_eq(attr, value)
    [Ident(attr), NotEq, Ident(value)] -> parse_not_eq(attr, value)
    [Ident(attr), Gte, Ident(value)] -> parse_gte(attr, value)
    [Ident(attr), Ident(kw), LParen, ..rest] ->
      case string.lowercase(kw) {
        "in" -> parse_in(attr, rest)
        _ -> Error(MalformedClause(render_clause(tokens)))
      }
    [] -> Error(EmptyClause)
    _ -> Error(MalformedClause(render_clause(tokens)))
  }
}

fn parse_eq(attr: String, value: String) -> Result(Predicate, ParseError) {
  case string.lowercase(attr) {
    "set_code" -> Ok(SetCodeIn([string.lowercase(value)]))
    "color_identity" ->
      card_attributes.parse_color_identity(value)
      |> result.map(ColorIdentityIs)
      |> result.replace_error(UnknownColorIdentity(value))
    "type" ->
      card_attributes.parse_card_type(value)
      |> result.map(CardTypeIs)
      |> result.replace_error(UnknownCardType(value))
    "finish" ->
      card_attributes.parse_finish(value)
      |> result.map(fn(f) { FinishIn([f]) })
      |> result.replace_error(UnknownFinish(value))
    "language" ->
      card_attributes.parse_language(value)
      |> result.map(fn(l) { LanguageIn([l]) })
      |> result.replace_error(UnknownLanguage(value))
    "supertype" ->
      card_attributes.parse_supertype(value)
      |> result.map(fn(s) { SupertypeIn([s]) })
      |> result.replace_error(UnknownSupertype(value))
    _ -> Error(UnknownAttribute(attr))
  }
}

fn parse_not_eq(attr: String, value: String) -> Result(Predicate, ParseError) {
  case string.lowercase(attr) {
    "set_code" -> Ok(SetCodeIsNot(string.lowercase(value)))
    "color_identity" ->
      card_attributes.parse_color_identity(value)
      |> result.map(ColorIdentityIsNot)
      |> result.replace_error(UnknownColorIdentity(value))
    "type" ->
      card_attributes.parse_card_type(value)
      |> result.map(CardTypeIsNot)
      |> result.replace_error(UnknownCardType(value))
    "finish" ->
      card_attributes.parse_finish(value)
      |> result.map(FinishIsNot)
      |> result.replace_error(UnknownFinish(value))
    "language" ->
      card_attributes.parse_language(value)
      |> result.map(LanguageIsNot)
      |> result.replace_error(UnknownLanguage(value))
    "supertype" ->
      card_attributes.parse_supertype(value)
      |> result.map(SupertypeIsNot)
      |> result.replace_error(UnknownSupertype(value))
    _ -> Error(UnknownAttribute(attr))
  }
}

fn parse_gte(attr: String, value: String) -> Result(Predicate, ParseError) {
  case string.lowercase(attr) {
    "rarity" ->
      card_attributes.parse_rarity(value)
      |> result.map(RarityAtLeast)
      |> result.replace_error(UnknownRarity(value))
    _ -> Error(UnknownAttribute(attr))
  }
}

fn parse_in(attr: String, rest: List(Token)) -> Result(Predicate, ParseError) {
  use items <- result.try(parse_list(rest, []))
  case string.lowercase(attr) {
    "set_code" -> Ok(SetCodeIn(list.map(items, string.lowercase)))
    "rarity" ->
      items
      |> list.try_map(fn(item) {
        card_attributes.parse_rarity(item)
        |> result.replace_error(UnknownRarity(item))
      })
      |> result.map(RarityIn)
    "finish" ->
      items
      |> list.try_map(fn(item) {
        card_attributes.parse_finish(item)
        |> result.replace_error(UnknownFinish(item))
      })
      |> result.map(FinishIn)
    "language" ->
      items
      |> list.try_map(fn(item) {
        card_attributes.parse_language(item)
        |> result.replace_error(UnknownLanguage(item))
      })
      |> result.map(LanguageIn)
    "supertype" ->
      items
      |> list.try_map(fn(item) {
        card_attributes.parse_supertype(item)
        |> result.replace_error(UnknownSupertype(item))
      })
      |> result.map(SupertypeIn)
    _ -> Error(UnknownAttribute(attr))
  }
}

// Consumes `item ("," item)* ")"` with nothing after the close paren.
fn parse_list(
  tokens: List(Token),
  acc: List(String),
) -> Result(List(String), ParseError) {
  case tokens, acc {
    [RParen], [] -> Error(EmptyList)
    [RParen], _ -> Ok(list.reverse(acc))
    [Ident(item), Comma, ..rest], _ -> parse_list(rest, [item, ..acc])
    [Ident(item), RParen], _ -> Ok(list.reverse([item, ..acc]))
    _, _ -> Error(MalformedClause("in (...)"))
  }
}

fn render_clause(tokens: List(Token)) -> String {
  tokens
  |> list.map(fn(t) {
    case t {
      Ident(s) -> s
      LParen -> "("
      RParen -> ")"
      Comma -> ","
      Eq -> "="
      NotEq -> "!="
      Gte -> ">="
    }
  })
  |> string.join(" ")
}

// --- Rendering ------------------------------------------------------------

// Canonical form; round-trips through parse.
pub fn to_string(predicate: Predicate) -> String {
  case predicate {
    SetCodeIn(codes) -> "set_code in (" <> string.join(codes, ", ") <> ")"
    RarityAtLeast(threshold) -> "rarity >= " <> rarity.to_string(threshold)
    RarityIn(rarities) ->
      "rarity in ("
      <> {
        rarities
        |> list.map(rarity.to_string)
        |> string.join(", ")
      }
      <> ")"
    ColorIdentityIs(identity) ->
      "color_identity = " <> card_attributes.color_identity_token(identity)
    CardTypeIs(card_type) ->
      "type = " <> card_attributes.card_type_to_string(card_type)
    FinishIn(finishes) ->
      "finish " <> equals_or_in_body(list.map(finishes, finish.to_string))
    LanguageIn(languages) ->
      "language " <> equals_or_in_body(list.map(languages, language.to_string))
    SupertypeIn(supertypes) ->
      "supertype "
      <> equals_or_in_body(list.map(
        supertypes,
        card_attributes.supertype_to_string,
      ))
    SetCodeIsNot(code) -> "set_code != " <> code
    ColorIdentityIsNot(identity) ->
      "color_identity != " <> card_attributes.color_identity_token(identity)
    CardTypeIsNot(card_type) ->
      "type != " <> card_attributes.card_type_to_string(card_type)
    FinishIsNot(value) -> "finish != " <> finish.to_string(value)
    LanguageIsNot(value) -> "language != " <> language.to_string(value)
    SupertypeIsNot(value) ->
      "supertype != " <> card_attributes.supertype_to_string(value)
    And(left, right) -> to_string(left) <> " and " <> to_string(right)
  }
}

// A single value reads as `= foil` — the issue's headline spelling, and the
// dominant case — while a longer list reads as `in (foil, etched)` like every
// other `_in` clause. Shared by FinishIn and LanguageIn, the DSL's two
// single-value-or-list clauses.
fn equals_or_in_body(values: List(String)) -> String {
  case values {
    [only] -> "= " <> only
    _ -> "in (" <> string.join(values, ", ") <> ")"
  }
}

// --- Matching -------------------------------------------------------------

// A clause referencing a catalog-enrichment attribute the card lacks is
// False, so the card cascades on to a later rule. finish and language come
// from the collection itself and are never absent (ADR 0010), so FinishIn and
// LanguageIn have no such case to handle. Negation doesn't flip this:
// ColorIdentityIsNot/CardTypeIsNot/SupertypeIsNot are also False for a card
// whose enrichment is absent (ADR 0017) — "the catalog doesn't know" is never
// a match, positive or negated. SupertypeIn/SupertypeIsNot test membership in
// card.supertypes rather than equality — a card can carry more than one
// supertype ("Basic Snow Land"), unlike every other attribute here.
pub fn matches(predicate: Predicate, card: PlannedCard) -> Bool {
  case predicate {
    SetCodeIn(codes) -> list.contains(codes, card_key.set_code_string(card.key))
    RarityAtLeast(threshold) ->
      case card.rarity {
        option.Some(rarity) ->
          card_attributes.rarity_at_least(rarity, threshold)
        option.None -> False
      }
    RarityIn(rarities) ->
      case card.rarity {
        option.Some(rarity) -> list.contains(rarities, rarity)
        option.None -> False
      }
    ColorIdentityIs(identity) ->
      case card.color_identity {
        option.Some(ci) -> ci == identity
        option.None -> False
      }
    CardTypeIs(card_type) ->
      case card.card_type {
        option.Some(ct) -> ct == card_type
        option.None -> False
      }
    FinishIn(finishes) -> list.contains(finishes, card.finish)
    LanguageIn(languages) -> list.contains(languages, card.language)
    SupertypeIn(supertypes) ->
      case card.supertypes {
        option.Some(card_supertypes) ->
          list.any(supertypes, list.contains(card_supertypes, _))
        option.None -> False
      }
    SetCodeIsNot(code) -> card_key.set_code_string(card.key) != code
    ColorIdentityIsNot(identity) ->
      case card.color_identity {
        option.Some(ci) -> ci != identity
        option.None -> False
      }
    CardTypeIsNot(card_type) ->
      case card.card_type {
        option.Some(ct) -> ct != card_type
        option.None -> False
      }
    FinishIsNot(value) -> card.finish != value
    LanguageIsNot(value) -> card.language != value
    SupertypeIsNot(value) ->
      case card.supertypes {
        option.Some(card_supertypes) -> !list.contains(card_supertypes, value)
        option.None -> False
      }
    And(left, right) -> matches(left, card) && matches(right, card)
  }
}
