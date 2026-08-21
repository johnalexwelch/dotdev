/**
 * Characterization tests for hook.ts
 * Pin current behavior at the interface — do not change behavior without updating these.
 */
import { describe, expect, it } from "bun:test";

import {
  decodeHookNotification,
  HookStartupError,
  runHook,
  type HookControlApi,
  type HookStartupOptions,
} from "../src/plugin/hook.ts";

describe("hook.ts", () => {
  describe("decodeHookNotification", () => {
    it("returns undefined when missing workspace info", () => {
      const env = {};
      expect(decodeHookNotification(env)).toBeUndefined();
    });

    it("returns undefined when missing context", () => {
      const env = {
        HERDR_WORKSPACE_ID: "ws-123",
        // missing HERDR_PLUGIN_CONTEXT_JSON
      };
      expect(decodeHookNotification(env)).toBeUndefined();
    });

    it("decodes from HERDR_WORKSPACE_ID and HERDR_PLUGIN_CONTEXT_JSON", () => {
      const env = {
        HERDR_WORKSPACE_ID: "workspace-abc",
        HERDR_PLUGIN_CONTEXT_JSON: JSON.stringify({ workspace_cwd: "/home/user/project" }),
      };
      const notification = decodeHookNotification(env);
      expect(notification).toBeDefined();
      expect(String(notification?.workspaceId)).toBe("workspace-abc");
      expect(notification?.cwd).toBe("/home/user/project");
    });

    it("prefers workspace_id from HERDR_PLUGIN_EVENT_JSON", () => {
      const env = {
        HERDR_WORKSPACE_ID: "fallback-id",
        HERDR_PLUGIN_EVENT_JSON: JSON.stringify({
          data: { workspace_id: "event-workspace-id" },
        }),
        HERDR_PLUGIN_CONTEXT_JSON: JSON.stringify({ workspace_cwd: "/path" }),
      };
      const notification = decodeHookNotification(env);
      expect(String(notification?.workspaceId)).toBe("event-workspace-id");
    });

    it("extracts workspace_id from nested workspace object", () => {
      const env = {
        HERDR_PLUGIN_EVENT_JSON: JSON.stringify({
          data: { workspace: { workspace_id: "nested-id" } },
        }),
        HERDR_PLUGIN_CONTEXT_JSON: JSON.stringify({ workspace_cwd: "/cwd" }),
      };
      const notification = decodeHookNotification(env);
      expect(String(notification?.workspaceId)).toBe("nested-id");
    });

    it("returns undefined for empty workspace_id", () => {
      const env = {
        HERDR_WORKSPACE_ID: "",
        HERDR_PLUGIN_CONTEXT_JSON: JSON.stringify({ workspace_cwd: "/path" }),
      };
      expect(decodeHookNotification(env)).toBeUndefined();
    });

    it("returns undefined for empty workspace_cwd", () => {
      const env = {
        HERDR_WORKSPACE_ID: "ws-123",
        HERDR_PLUGIN_CONTEXT_JSON: JSON.stringify({ workspace_cwd: "" }),
      };
      expect(decodeHookNotification(env)).toBeUndefined();
    });

    it("returns undefined for malformed JSON", () => {
      const env = {
        HERDR_WORKSPACE_ID: "ws-123",
        HERDR_PLUGIN_CONTEXT_JSON: "not-json",
      };
      expect(decodeHookNotification(env)).toBeUndefined();
    });
  });

  describe("HookStartupError", () => {
    it("has correct tag and name", () => {
      const error = new HookStartupError("lock", "Lock acquisition failed");
      expect(error._tag).toBe("HookStartupError");
      expect(error.name).toBe("HookStartupError");
    });

    it("captures operation", () => {
      const lockError = new HookStartupError("lock", "msg");
      expect(lockError.operation).toBe("lock");

      const readinessError = new HookStartupError("readiness", "msg");
      expect(readinessError.operation).toBe("readiness");

      const paneError = new HookStartupError("open_pane", "msg");
      expect(paneError.operation).toBe("open_pane");
    });

    it("captures message", () => {
      const error = new HookStartupError("lock", "Custom error message");
      expect(error.message).toBe("Custom error message");
    });
  });

  describe("runHook", () => {
    const makeNotificationEnv = () => ({
      HERDR_WORKSPACE_ID: "test-workspace",
      HERDR_PLUGIN_CONTEXT_JSON: JSON.stringify({ workspace_cwd: "/test/path" }),
    });

    it("returns Skipped when notification cannot be decoded", async () => {
      const result = await runHook({ environment: {} });
      expect(result._tag).toBe("Skipped");
      if (result._tag === "Skipped") {
        expect(result.reason).toBe("missing_workspace_or_cwd");
      }
    });

    it("returns Notified with openedPane=false when control accepts notification", async () => {
      let notifiedWith: any = null;
      const mockControl: HookControlApi = {
        controlSocketPath: () => "/mock/control.sock",
        prepareControlSocket: async () => {},
        prepareControlSocketDirectory: async () => {},
        notifyControl: async (_path, notification) => {
          notifiedWith = notification;
        },
      };

      const result = await runHook({
        environment: makeNotificationEnv(),
        control: mockControl,
        now: () => 0,
      });

      expect(result._tag).toBe("Notified");
      if (result._tag === "Notified") {
        expect(result.openedPane).toBe(false);
      }
      expect(notifiedWith).toEqual({
        workspaceId: "test-workspace",
        cwd: "/test/path",
      });
    });

    it("uses injected controlSocketPath", async () => {
      let usedPath = "";
      const mockControl: HookControlApi = {
        controlSocketPath: () => "/custom/socket/path.sock",
        prepareControlSocket: async () => {},
        prepareControlSocketDirectory: async (path) => {
          usedPath = path;
        },
        notifyControl: async () => {},
      };

      await runHook({
        environment: makeNotificationEnv(),
        control: mockControl,
        now: () => 0,
      });

      expect(usedPath).toBe("/custom/socket/path.sock");
    });

    it("times out when control never responds and pane fails", async () => {
      const { ControlUnavailable } = await import("../src/plugin/control.ts");

      let time = 0;
      const mockControl: HookControlApi = {
        controlSocketPath: () => "/mock.sock",
        prepareControlSocket: async () => {},
        prepareControlSocketDirectory: async () => {},
        notifyControl: async () => {
          throw new ControlUnavailable("/mock.sock", "timeout");
        },
      };

      const options: HookStartupOptions = {
        environment: makeNotificationEnv(),
        control: mockControl,
        now: () => time,
        sleep: async (ms) => {
          time += ms;
        },
        token: () => "mock-token",
        openPane: async () => {
          // ponytail: simulate pane open succeeding but control still unavailable
          throw new Error("Pane failed");
        },
      };

      await expect(runHook(options)).rejects.toThrow();
    });
  });
});
