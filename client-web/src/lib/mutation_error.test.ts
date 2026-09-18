import { describe, expect, it } from "vitest";
import { createMutationError } from "./mutation_error";

describe("createMutationError", () => {
  it("has no message for any scope before a report", () => {
    const { messageFor } = createMutationError();
    expect(messageFor()).toBeNull();
    expect(messageFor("add")).toBeNull();
  });

  it("surfaces a reported error only under its own scope", () => {
    const { report, messageFor } = createMutationError();
    report(new Error("HTTP status 400: invalid inventory rule expression"), "add");
    expect(messageFor("add")).toBe("HTTP status 400: invalid inventory rule expression");
    expect(messageFor("rule-1")).toBeNull();
    expect(messageFor()).toBeNull();
  });

  it("supports the unscoped (page-level) form", () => {
    const { report, messageFor } = createMutationError();
    report(new Error("boom"));
    expect(messageFor()).toBe("boom");
    expect(messageFor("add")).toBeNull();
  });

  it("a later report replaces the earlier one, even under a different scope", () => {
    const { report, messageFor } = createMutationError();
    report(new Error("first"), "add");
    report(new Error("second"), "rule-1");
    expect(messageFor("add")).toBeNull();
    expect(messageFor("rule-1")).toBe("second");
  });

  it("clear discards the current error regardless of scope", () => {
    const { report, clear, messageFor } = createMutationError();
    report(new Error("boom"), "add");
    clear();
    expect(messageFor("add")).toBeNull();
  });

  it("maps a non-Error throw to the generic message", () => {
    const { report, messageFor } = createMutationError();
    report("not an error object", "add");
    expect(messageFor("add")).toBe("Unknown application error");
  });
});
