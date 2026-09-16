// The identity of a kind of owned physical copy is (printing, finish,
// language) — ADR 0010. Both value sets are closed and shared by every part
// of the client that touches owned copies (collection, add, import).

export type Finish = "nonfoil" | "foil" | "etched";
export const FINISHES: readonly Finish[] = ["nonfoil", "foil", "etched"];
export const DEFAULT_FINISH: Finish = "nonfoil";

export type Language =
  | "en"
  | "es"
  | "fr"
  | "de"
  | "it"
  | "pt"
  | "ja"
  | "ko"
  | "ru"
  | "zhs"
  | "zht"
  | "he"
  | "la"
  | "grc"
  | "ar"
  | "sa"
  | "ph"
  | "qya";
export const LANGUAGES: readonly Language[] = [
  "en",
  "es",
  "fr",
  "de",
  "it",
  "pt",
  "ja",
  "ko",
  "ru",
  "zhs",
  "zht",
  "he",
  "la",
  "grc",
  "ar",
  "sa",
  "ph",
  "qya",
];
export const DEFAULT_LANGUAGE: Language = "en";

// The wire spelling is the uppercase of ours (Skir's generated Initializer
// type accepts these literals directly, for either the commands or queries
// module's separately-generated Finish/Language classes).
export function toWireFinish(finish: Finish): Uppercase<Finish> {
  return finish.toUpperCase() as Uppercase<Finish>;
}

export function toWireLanguage(language: Language): Uppercase<Language> {
  return language.toUpperCase() as Uppercase<Language>;
}

// A stored copy's finish/language always parses (the server validates them at
// write time); an unrecognized kind can only mean version skew between client
// and server, so it falls back to the default rather than breaking the badge.
export function fromWireFinishKind(kind: string): Finish {
  switch (kind) {
    case "NONFOIL":
      return "nonfoil";
    case "FOIL":
      return "foil";
    case "ETCHED":
      return "etched";
    default:
      return DEFAULT_FINISH;
  }
}

export function fromWireLanguageKind(kind: string): Language {
  const lower = kind.toLowerCase();
  return (LANGUAGES as readonly string[]).includes(lower) ? (lower as Language) : DEFAULT_LANGUAGE;
}
