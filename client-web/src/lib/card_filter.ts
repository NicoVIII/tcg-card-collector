// Name/set-code filter shared by the Catalog and Collection pages. It lives
// in the URL (`?name=&set=`) so a reload or a shared link keeps the search
// (client-web/AGENTS.md's useSearchParams rule) — see placement_focus.ts for
// the same single-param pattern this mirrors.
export type CardFilter = {
  name: string;
  set_code: string;
};

export const EMPTY_CARD_FILTER: CardFilter = { name: "", set_code: "" };

function firstValue(value: string | string[] | undefined): string {
  const raw = Array.isArray(value) ? value[0] : value;
  return raw ?? "";
}

export function filterFromSearchParams(params: {
  name?: string | string[];
  set?: string | string[];
}): CardFilter {
  return { name: firstValue(params.name), set_code: firstValue(params.set) };
}

// Blank clears the URL param instead of writing `?name=`, matching the
// placement_focus precedent of using `undefined` to remove a param.
export function searchParamsFromFilter(filter: CardFilter): {
  name: string | undefined;
  set: string | undefined;
} {
  const name = filter.name.trim();
  const set_code = filter.set_code.trim();
  return { name: name === "" ? undefined : name, set: set_code === "" ? undefined : set_code };
}

// The wire type is `string | null` and camelCase (`setCode`), like every
// other generated request field; a blank filter is "no filter" there too.
export function toWireFilter(filter: CardFilter): { name: string | null; setCode: string | null } {
  const params = searchParamsFromFilter(filter);
  return { name: params.name ?? null, setCode: params.set ?? null };
}
