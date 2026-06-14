pub type CardRarity {
  Common
  Uncommon
  Rare
  Mythic
  Special
  Bonus
}

pub fn parse(raw: String) -> Result(CardRarity, Nil) {
  case raw {
    "common" -> Ok(Common)
    "uncommon" -> Ok(Uncommon)
    "rare" -> Ok(Rare)
    "mythic" -> Ok(Mythic)
    "special" -> Ok(Special)
    "bonus" -> Ok(Bonus)
    _ -> Error(Nil)
  }
}

pub fn to_string(rarity: CardRarity) -> String {
  case rarity {
    Common -> "common"
    Uncommon -> "uncommon"
    Rare -> "rare"
    Mythic -> "mythic"
    Special -> "special"
    Bonus -> "bonus"
  }
}
