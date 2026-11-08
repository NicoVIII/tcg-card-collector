import { skirClient } from "../http/skir_rpc";
import {
  fromWireFinishKind,
  fromWireLanguageKind,
  toWireFinish,
  toWireLanguage,
  type Finish,
  type Language,
} from "../collection/copy_kind";
import {
  AddToManagedLocation,
  AddToManagedLocationRequest,
  CreateManagedLocation,
  CreateManagedLocationRequest,
  DeleteManagedLocation,
  DeleteManagedLocationRequest,
  ManagedCopy as RpcManagedCopy,
  RemoveFromManagedLocation,
  RemoveFromManagedLocationRequest,
  RenameManagedLocation,
  RenameManagedLocationRequest,
} from "../skirout/inventory_planning/commands.js";
import {
  ListManagedLocations,
  ListManagedLocationsRequest,
  ManagedLocationList as RpcManagedLocationList,
} from "../skirout/inventory_planning/queries.js";

// A managed location (ADR 0022): a named location whose contents are an
// explicit membership list, taken before any rule runs. Only decks so far.
export type ManagedLocationKind = "deck";

// One kind of copy and how many — a member of a managed location, or a
// change to its membership.
export type ManagedCopy = {
  set_code: string;
  collector_number: string;
  finish: Finish;
  language: Language;
  quantity: number;
};

export type ManagedLocation = {
  id: string;
  name: string;
  kind: ManagedLocationKind;
  // The whole membership, including copies the collection no longer owns —
  // the projection's `shortfall` says which of these are missing.
  members: ManagedCopy[];
};

function toManagedLocations(response: RpcManagedLocationList): ManagedLocation[] {
  return response.locations.map((location) => ({
    id: location.id,
    name: location.name,
    kind: "deck",
    members: location.members.map((member) => ({
      set_code: member.setCode,
      collector_number: member.collectorNumber,
      finish: fromWireFinishKind(member.finish.union.kind),
      language: fromWireLanguageKind(member.language.union.kind),
      quantity: member.quantity,
    })),
  }));
}

function toRpcCopies(copies: ManagedCopy[]) {
  return copies.map((copy) =>
    RpcManagedCopy.create({
      setCode: copy.set_code,
      collectorNumber: copy.collector_number,
      finish: toWireFinish(copy.finish),
      language: toWireLanguage(copy.language),
      quantity: copy.quantity,
    }),
  );
}

export async function listManagedLocations(): Promise<ManagedLocation[]> {
  const response = await skirClient.invokeRemote(
    ListManagedLocations,
    ListManagedLocationsRequest.create({ unit: true }),
    "POST",
  );

  return toManagedLocations(response);
}

export async function createManagedLocation(location: {
  id: string;
  name: string;
  kind: ManagedLocationKind;
}): Promise<void> {
  await skirClient.invokeRemote(
    CreateManagedLocation,
    CreateManagedLocationRequest.create({
      id: location.id,
      name: location.name,
      kind: "DECK",
    }),
  );
}

export async function renameManagedLocation(id: string, name: string): Promise<void> {
  await skirClient.invokeRemote(
    RenameManagedLocation,
    RenameManagedLocationRequest.create({ id, name }),
  );
}

export async function deleteManagedLocation(id: string): Promise<void> {
  await skirClient.invokeRemote(DeleteManagedLocation, DeleteManagedLocationRequest.create({ id }));
}

export async function addToManagedLocation(id: string, copies: ManagedCopy[]): Promise<void> {
  await skirClient.invokeRemote(
    AddToManagedLocation,
    AddToManagedLocationRequest.create({ id, copies: toRpcCopies(copies) }),
  );
}

export async function removeFromManagedLocation(id: string, copies: ManagedCopy[]): Promise<void> {
  await skirClient.invokeRemote(
    RemoveFromManagedLocation,
    RemoveFromManagedLocationRequest.create({ id, copies: toRpcCopies(copies) }),
  );
}
