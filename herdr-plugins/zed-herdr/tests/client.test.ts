/**
 * Characterization tests for client.ts
 * Pin current behavior at the interface — do not change behavior without updating these.
 */
import { describe, expect, it } from "bun:test";

import { resolveHerdRSocketPath } from "../src/herdr/client.ts";
import {
  StaleWorkspaceGeneration,
  UnsupportedHerdRProtocol,
  WorkspaceSourceProtocolError,
  WorkspaceSourceTransportError,
} from "../src/domain/errors.ts";

describe("client.ts", () => {
  describe("resolveHerdRSocketPath", () => {
    // ponytail: duplicates control.test.ts but client.ts is the canonical export
    it("uses HERDR_SOCKET_PATH when set", () => {
      const env = { HERDR_SOCKET_PATH: "/custom/herdr.sock" };
      expect(resolveHerdRSocketPath(env)).toBe("/custom/herdr.sock");
    });

    it("uses XDG_CONFIG_HOME for default path", () => {
      const env = { XDG_CONFIG_HOME: "/xdg/config" };
      expect(resolveHerdRSocketPath(env)).toBe("/xdg/config/herdr/herdr.sock");
    });

    it("uses session-specific path with HERDR_SESSION", () => {
      const env = {
        XDG_CONFIG_HOME: "/xdg/config",
        HERDR_SESSION: "test-session",
      };
      expect(resolveHerdRSocketPath(env)).toBe(
        "/xdg/config/herdr/sessions/test-session/herdr.sock",
      );
    });

    it("falls back to HOME/.config without XDG_CONFIG_HOME", () => {
      const env = { HOME: "/home/testuser" };
      expect(resolveHerdRSocketPath(env)).toBe("/home/testuser/.config/herdr/herdr.sock");
    });
  });
});

describe("domain/errors.ts", () => {
  describe("WorkspaceSourceTransportError", () => {
    it("captures operation and message", () => {
      const error = new WorkspaceSourceTransportError({
        operation: "connect",
        message: "Connection failed",
      });
      expect(error._tag).toBe("WorkspaceSourceTransportError");
      expect(error.operation).toBe("connect");
      expect(error.message).toBe("Connection failed");
    });

    it("accepts all operation types", () => {
      const operations = ["connect", "request", "subscribe", "read"] as const;
      for (const operation of operations) {
        const error = new WorkspaceSourceTransportError({ operation, message: "test" });
        expect(error.operation).toBe(operation);
      }
    });
  });

  describe("WorkspaceSourceProtocolError", () => {
    it("captures operation and message", () => {
      const error = new WorkspaceSourceProtocolError({
        operation: "decode",
        message: "Invalid JSON",
      });
      expect(error._tag).toBe("WorkspaceSourceProtocolError");
      expect(error.operation).toBe("decode");
      expect(error.message).toBe("Invalid JSON");
    });

    it("accepts all operation types", () => {
      const operations = ["decode", "response", "subscription"] as const;
      for (const operation of operations) {
        const error = new WorkspaceSourceProtocolError({ operation, message: "test" });
        expect(error.operation).toBe(operation);
      }
    });
  });

  describe("StaleWorkspaceGeneration", () => {
    it("captures generation", () => {
      // ponytail: generation is branded type, use any for test construction
      const error = new StaleWorkspaceGeneration({ generation: 42 as any });
      expect(error._tag).toBe("StaleWorkspaceGeneration");
      expect(Number(error.generation)).toBe(42);
    });
  });

  describe("UnsupportedHerdRProtocol", () => {
    it("captures expected and actual protocol version", () => {
      // expected is Literal(17), actual is an exit code number
      const error = new UnsupportedHerdRProtocol({
        expected: 17,
        actual: 16,
      });
      expect(error._tag).toBe("UnsupportedHerdRProtocol");
      expect(error.expected).toBe(17);
      expect(error.actual).toBe(16);
    });
  });
});
