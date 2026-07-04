// Representative, truncated sample of a real deckstats.net collection export,
// provided by the owner. Kept as a string constant so the deckstats parser has
// a faithful test fixture (header ordering, quoted fields, per-key duplicates,
// foil/non-English rows, empty collector numbers, promo sets).
//
// Full deckstats export header (column order as exported):
//   amount, card_name, is_foil, is_pinned, is_signed, set_id, set_code,
//   collector_number, language, condition, comment, added
//
// Notable rows this sample exercises:
//   - M19/85 appears twice (de + en) -> quantities aggregate to 3
//   - M15/85 appears twice (de + en) -> quantities aggregate to 4
//   - MH2 "Abundant Harvest" 354 and 147 share a name but are distinct keys
//   - a foil row (Aboshan's Desire, is_foil=1) -> foil flag is dropped
//   - rows with an empty collector_number (ODY, OGW x2, SCG, HOU, SOI) -> rejected
//   - a promo set (PLIST) and a double-faced card name (SOI)
export const DECKSTATS_FIXTURE_CSV = `amount,card_name,is_foil,is_pinned,is_signed,set_id,set_code,collector_number,language,condition,comment,added
1,"Abattoir Ghoul",,,,,"ISD","85","de",,,
2,"Abiding Grace",,,,,"MH2","1","en",,,
1,"Abnormal Endurance",,,,,"M19","85","de",,,
2,"Abnormal Endurance",,,,,"M19","85","en",,,
1,"Aboshan's Desire",1,,,,"ODY",,"en",,,
1,"Absorb",,,,,"RNA","151","en",,,
1,"Absorb Identity",,,,,"KHM","383","en",,,
1,"Absorb Vis",,,,,"CON","40","de",,,
1,"Abstruse Interference",,,,,"OGW",,"en",,,
2,"Abstruse Interference",,,,,"OGW",,"de",,,
1,"Abundant Growth",,,,,"EMA","156","en",,,
1,"Abundant Harvest",,,,,"MH2","354","en",,,
3,"Abundant Harvest",,,,,"MH2","147","en",,,
1,"Abyssal Gatekeeper",,,,,"WTH","59","en",,,
1,"Abzan Charm",,,,,"KTK","161","en",,,
5,"Academic Dispute",,,,,"STX","91","en",,,
2,"Academic Probation",,,,,"STX","7","en",,,
2,"Academy Drake",,,,,"DOM","40","de",,,
1,"Academy Elite",,,,,"PLIST","354","en",,,
1,"Accelerated Mutation",,,,,"SCG",,"en",,,
3,"Access Tunnel",,,,,"STX","262","en",,,
2,"Acclaimed Contender",,,,,"ELD","1","en",,,
2,"Accomplished Alchemist",,,,,"STX","119","en",,,
2,"Accursed Horde",,,,,"HOU",,"en",,,
2,"Accursed Spirit",,,,,"M15","85","de",,,
2,"Accursed Spirit",,,,,"M15","85","en",,,
1,"Accursed Witch // Infectious Curse",,,,,"SOI",,"en",,,
2,"Acidic Slime",,,,,"M13","159","de",,,
1,"Acolyte of Affliction",,,,,"THB","206","en",,,
`;
