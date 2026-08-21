/**
 * Characterization tests for control.ts
 * Pin current behavior at the interface — do not change behavior without updating these.
 */
import { describe, expect, it } from "bun:test";

import {
  AlreadyRunning,
  CONTROL_DAEMON_IDENTITY,
  CONTROL_SOCKET_MAX_BYTES,
  CONTROL_SOCKET_MODE,
  ControlProtocolError,
  ControlUnavailable,
  type ControlSocketConnector,
  controlSocketPath,
  probeControlSocket,
  UnsafeControlSocket,
} from "../src/plugin/control.ts";
import { resolveHerdRSocketPath } from "../src/herdr/client.ts";

describe("control.ts", () => {
  describe("constants", () => {
    it("CONTROL_SOCKET_MAX_BYTES is 64KiB", () => {
      expect(CONTROL_SOCKET_MAX_BYTES).toBe(64 * 1024);
    });

    it("CONTROL_SOCKET_MODE is 0o600", () => {
      expect(CONTROL_SOCKET_MODE).toBe(0o600);
    });

    it("CONTROL_DAEMON_IDENTITY is artisann.zed-herdr:daemon", () => {
      expect(CONTROL_DAEMON_IDENTITY).toBe("artisann.zed-herdr:daemon");
    });
  });

  describe("resolveHerdRSocketPath", () => {
    it("uses HERDR_SOCKET_PATH when set", () => {
      const env = { HERDR_SOCKET_PATH: "/custom/herdr.sock" };
      expect(resolveHerdRSocketPath(env)).toBe("/custom/herdr.sock");
    });

    it("uses XDG_CONFIG_HOME when HERDR_SOCKET_PATH is empty", () => {
      const env = {
        HERDR_SOCKET_PATH: "",
        XDG_CONFIG_HOME: "/xdg/config",
        HOME: "/home/user",
      };
      expect(resolveHerdRSocketPath(env)).toBe("/xdg/config/herdr/herdr.sock");
    });

    it("falls back to HOME/.config when XDG_CONFIG_HOME is empty", () => {
      const env = {
        HERDR_SOCKET_PATH: "",
        XDG_CONFIG_HOME: "",
        HOME: "/home/user",
      };
      expect(resolveHerdRSocketPath(env)).toBe("/home/user/.config/herdr/herdr.sock");
    });

    it("uses HERDR_SESSION for session-specific socket", () => {
      const env = {
        XDG_CONFIG_HOME: "/xdg/config",
        HERDR_SESSION: "my-session",
      };
      expect(resolveHerdRSocketPath(env)).toBe("/xdg/config/herdr/sessions/my-session/herdr.sock");
    });

    it("ignores empty HERDR_SESSION", () => {
      const env = {
        XDG_CONFIG_HOME: "/xdg/config",
        HERDR_SESSION: "",
      };
      expect(resolveHerdRSocketPath(env)).toBe("/xdg/config/herdr/herdr.sock");
    });
  });

  describe("controlSocketPath", () => {
    it("derives path from HerdR socket path with sha256 digest", () => {
      const env = {
        HERDR_SOCKET_PATH: "/custom/herdr.sock",
        XDG_RUNTIME_DIR: "/run/user/1000",
      };
      const path = controlSocketPath(env);
      // ponytail: exact digest depends on implementation, pin pattern only
      expect(path).toMatch(/^\/run\/user\/1000\/zed-herdr\/[a-f0-9]{16}\.sock$/);
    });

    it("uses HerdR socket directory when XDG_RUNTIME_DIR is empty", () => {
      const env = {
        HERDR_SOCKET_PATH: "/custom/path/herdr.sock",
        XDG_RUNTIME_DIR: "",
      };
      const path = controlSocketPath(env);
      expect(path).toMatch(/^\/custom\/path\/zed-herdr\/[a-f0-9]{16}\.sock$/);
    });
  });

  describe("probeControlSocket", () => {
    it("returns true when socket accepts connection", async () => {
      const mockConnector: ControlSocketConnector = {
        connect: () =>
          Promise.resolve({
            end: () => {},
            terminate: () => {},
          } as any),
      };
      const result = await probeControlSocket("/test.sock", 100, mockConnector);
      expect(result).toBe(true);
    });

    it("returns false when connection is refused (ECONNREFUSED)", async () => {
      const mockConnector: ControlSocketConnector = {
        connect: () => {
          const err: any = new Error("Connection refused");
          err.code = "ECONNREFUSED";
          return Promise.reject(err);
        },
      };
      const result = await probeControlSocket("/test.sock", 100, mockConnector);
      expect(result).toBe(false);
    });

    it("returns false when socket does not exist (ENOENT)", async () => {
      const mockConnector: ControlSocketConnector = {
        connect: () => {
          const err: any = new Error("No such file");
          err.code = "ENOENT";
          return Promise.reject(err);
        },
      };
      const result = await probeControlSocket("/test.sock", 100, mockConnector);
      expect(result).toBe(false);
    });

    it("throws UnsafeControlSocket on non-ECONNREFUSED/ENOENT errors", async () => {
      const mockConnector: ControlSocketConnector = {
        connect: () => {
          const err: any = new Error("Permission denied");
          err.code = "EACCES";
          return Promise.reject(err);
        },
      };
      await expect(probeControlSocket("/test.sock", 100, mockConnector)).rejects.toBeInstanceOf(
        UnsafeControlSocket,
      );
    });

    it("throws UnsafeControlSocket on timeout", async () => {
      const mockConnector: ControlSocketConnector = {
        connect: () => new Promise(() => {}), // never resolves
      };
      await expect(probeControlSocket("/test.sock", 10, mockConnector)).rejects.toBeInstanceOf(
        UnsafeControlSocket,
      );
    });
  });

  describe("error classes", () => {
    it("AlreadyRunning has correct tag and message", () => {
      const error = new AlreadyRunning("/path/to/socket");
      expect(error._tag).toBe("AlreadyRunning");
      expect(error.name).toBe("AlreadyRunning");
      expect(error.path).toBe("/path/to/socket");
      expect(error.message).toContain("/path/to/socket");
    });

    it("UnsafeControlSocket captures reason", () => {
      const error = new UnsafeControlSocket("/socket", "foreign_owner");
      expect(error._tag).toBe("UnsafeControlSocket");
      expect(error.name).toBe("UnsafeControlSocket");
      expect(error.path).toBe("/socket");
      expect(error.reason).toBe("foreign_owner");
    });

    it("UnsafeControlSocket accepts all reason values", () => {
      const reasons = [
        "foreign_owner",
        "not_socket",
        "symlink",
        "changed_inode",
        "lstat_failed",
        "probe_failed",
        "not_directory",
        "unsafe_mode",
        "unsafe_parent",
      ] as const;
      for (const reason of reasons) {
        const error = new UnsafeControlSocket("/sock", reason);
        expect(error.reason).toBe(reason);
      }
    });

    it("ControlUnavailable captures operation and cause", () => {
      const cause = new Error("network failure");
      const error = new ControlUnavailable("/socket", "connect", cause);
      expect(error._tag).toBe("ControlUnavailable");
      expect(error.path).toBe("/socket");
      expect(error.operation).toBe("connect");
      expect(error.cause).toBe(cause);
    });

    it("ControlProtocolError captures detail", () => {
      const error = new ControlProtocolError("/socket", "invalid JSON");
      expect(error._tag).toBe("ControlProtocolError");
      expect(error.path).toBe("/socket");
      expect(error.detail).toBe("invalid JSON");
    });
  });
});
