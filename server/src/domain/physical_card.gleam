import domain/card_definition.{type CardDefinitionId}

pub type PhysicalCard {
  PhysicalCard(id: String, card_definition_id: CardDefinitionId)
}
