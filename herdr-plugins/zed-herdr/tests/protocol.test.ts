/**
 * Characterization tests for protocol.ts
 * Pin schema validation behavior — do not change without updating these.
 */
import { describe, expect, it } from "bun:test";
import * as Schema from "effect/Schema";

import {
  ControlRequest,
  ControlResponse,
  DaemonHealth,
  HookNotification,
} from "../src/plugin/protocol.ts";

describe("protocol.ts", () => {
  describe("HookNotification schema", () => {
    it("accepts valid notification", () => {
      const input = { workspaceId: "ws-123", cwd: "/path/to/project" };
      const result = Schema.decodeUnknownEither(HookNotification)(input);
      expect(result._tag).toBe("Right");
    });

    it("rejects empty workspaceId", () => {
      const input = { workspaceId: "", cwd: "/path" };
      const result = Schema.decodeUnknownEither(HookNotification)(input);
      expect(result._tag).toBe("Left");
    });

    it("rejects empty cwd", () => {
      const input = { workspaceId: "ws-123", cwd: "" };
      const result = Schema.decodeUnknownEither(HookNotification)(input);
      expect(result._tag).toBe("Left");
    });

    it("rejects missing fields", () => {
      expect(Schema.decodeUnknownEither(HookNotification)({})._tag).toBe("Left");
      expect(Schema.decodeUnknownEither(HookNotification)({ workspaceId: "x" })._tag).toBe("Left");
      expect(Schema.decodeUnknownEither(HookNotification)({ cwd: "/x" })._tag).toBe("Left");
    });
  });

  describe("ControlRequest schema", () => {
    it("accepts health request", () => {
      const input = { type: "health" };
      const result = Schema.decodeUnknownEither(ControlRequest)(input);
      expect(result._tag).toBe("Right");
    });

    it("accepts toggle request", () => {
      const input = { type: "toggle" };
      const result = Schema.decodeUnknownEither(ControlRequest)(input);
      expect(result._tag).toBe("Right");
    });

    it("accepts notify request with valid notification", () => {
      const input = {
        type: "notify",
        notification: { workspaceId: "ws-123", cwd: "/path" },
      };
      const result = Schema.decodeUnknownEither(ControlRequest)(input);
      expect(result._tag).toBe("Right");
    });

    it("rejects unknown request type", () => {
      const input = { type: "unknown" };
      const result = Schema.decodeUnknownEither(ControlRequest)(input);
      expect(result._tag).toBe("Left");
    });

    it("rejects notify with invalid notification", () => {
      const input = { type: "notify", notification: { workspaceId: "" } };
      const result = Schema.decodeUnknownEither(ControlRequest)(input);
      expect(result._tag).toBe("Left");
    });
  });

  describe("ControlResponse schema", () => {
    it("accepts simple ok response", () => {
      const input = { ok: true };
      const result = Schema.decodeUnknownEither(ControlResponse)(input);
      expect(result._tag).toBe("Right");
    });

    it("accepts health response with daemon", () => {
      const input = {
        ok: true,
        daemon: {
          identity: "artisann.zed-herdr:daemon",
          paneId: "pane-1",
          pid: 12345,
          startedAt: "2024-01-01T00:00:00Z",
        },
      };
      const result = Schema.decodeUnknownEither(ControlResponse)(input);
      expect(result._tag).toBe("Right");
    });

    it("accepts toggle response with enabled", () => {
      const input = { ok: true, enabled: true };
      const result = Schema.decodeUnknownEither(ControlResponse)(input);
      expect(result._tag).toBe("Right");
    });

    it("accepts failure response with error", () => {
      const validErrors = ["invalid_request", "payload_too_large", "server_failure"] as const;
      for (const error of validErrors) {
        const input = { ok: false, error };
        const result = Schema.decodeUnknownEither(ControlResponse)(input);
        expect(result._tag).toBe("Right");
      }
    });

    it("rejects failure with unknown error", () => {
      const input = { ok: false, error: "unknown_error" };
      const result = Schema.decodeUnknownEither(ControlResponse)(input);
      expect(result._tag).toBe("Left");
    });
  });

  describe("DaemonHealth schema", () => {
    it("accepts valid daemon health", () => {
      const input = {
        identity: "artisann.zed-herdr:daemon",
        paneId: "pane-123",
        pid: 42,
        startedAt: "2024-01-01T00:00:00.000Z",
      };
      const result = Schema.decodeUnknownEither(DaemonHealth)(input);
      expect(result._tag).toBe("Right");
    });

    it("accepts null paneId", () => {
      const input = {
        identity: "artisann.zed-herdr:daemon",
        paneId: null,
        pid: 42,
        startedAt: "2024-01-01T00:00:00.000Z",
      };
      const result = Schema.decodeUnknownEither(DaemonHealth)(input);
      expect(result._tag).toBe("Right");
    });

    it("rejects wrong identity", () => {
      const input = {
        identity: "wrong-identity",
        paneId: null,
        pid: 42,
        startedAt: "2024-01-01T00:00:00.000Z",
      };
      const result = Schema.decodeUnknownEither(DaemonHealth)(input);
      expect(result._tag).toBe("Left");
    });

    it("rejects negative pid", () => {
      const input = {
        identity: "artisann.zed-herdr:daemon",
        paneId: null,
        pid: -1,
        startedAt: "2024-01-01T00:00:00.000Z",
      };
      const result = Schema.decodeUnknownEither(DaemonHealth)(input);
      expect(result._tag).toBe("Left");
    });

    it("rejects empty startedAt", () => {
      const input = {
        identity: "artisann.zed-herdr:daemon",
        paneId: null,
        pid: 42,
        startedAt: "",
      };
      const result = Schema.decodeUnknownEither(DaemonHealth)(input);
      expect(result._tag).toBe("Left");
    });
  });
});
