{
  "mcpServers": {
    "iris-staging": {
      "command": "/Users/alexwelch/.local/bin/iris-mcp-bridge",
      "env": {
        "IRIS_MCP_GATEWAY_URL": "https://iris-staging.us-east-1-dataeng.internal.classdojo-ops.com/mcp",
        "IRIS_API_KEY": "op://Private/Claude Desktop MCP/iris_staging_api_key",
        "IRIS_MCP_USER_LABEL": "alex.welch@classdojo.com"
      }
    },
    "iris-prod": {
      "command": "/Users/alexwelch/.local/bin/iris-mcp-bridge",
      "env": {
        "IRIS_MCP_GATEWAY_URL": "https://iris.us-east-1-dataeng.internal.classdojo-ops.com/mcp",
        "IRIS_API_KEY": "op://Private/Claude Desktop MCP/iris_prod_api_key",
        "IRIS_MCP_USER_LABEL": "alex.welch@classdojo.com"
      }
    },
    "github": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-e",
        "GITHUB_PERSONAL_ACCESS_TOKEN",
        "ghcr.io/github/github-mcp-server"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "op://Private/Claude Desktop MCP/github_pat"
      }
    }
  },
  "coworkUserFilesPath": "/Users/alexwelch/Documents/Claude",
  "preferences": {
    "launchPreviewPersistedWorkspaces": [],
    "launchPreviewSessionScopedSessions": [],
    "localAgentModeTrustedFolders": [
      "/Users/alexwelch/projects/iris",
      "/Users/alexwelch/projects/chief-of-staff",
      "/Users/alexwelch/dotdev",
      "/Users/alexwelch/dojo/astronomer",
      "/Users/alexwelch/projects/nora",
      "/Users/alexwelch/projects/cora",
      "/Users/alexwelch/Downloads",
      "/Users/alexwelch/.claude/skills",
      "/Users/alexwelch/projects/mira",
      "/Users/alexwelch/Documents/Home/Areas/DnD/GM/Chronicles of the Uncrowned King",
      "/Users/alexwelch/Desktop",
      "/Users/alexwelch/projects/agents/wren"
    ],
    "coworkScheduledTasksEnabled": true,
    "coworkHipaaRestricted": false,
    "ccdScheduledTasksEnabled": true,
    "sidebarMode": "epitaxy",
    "bypassPermissionsGateByAccount": {
      "8b39e467-f7fd-42a9-be9b-a6fa6abd9a15": true,
      "8589227c-49e8-4097-bf02-129d4b45bcb4": false
    },
    "dockBounceEnabled": true,
    "coworkWebSearchEnabled": true,
    "coworkModelAutoFallbackByAccount": {
      "8b39e467-f7fd-42a9-be9b-a6fa6abd9a15": true,
      "8589227c-49e8-4097-bf02-129d4b45bcb4": true
    },
    "keepAwakeEnabled": true,
    "coworkOnboardingResumeStep": null,
    "chicagoEnabled": true,
    "remoteToolsDeviceName": "alex-welch-dojo",
    "ccAutoArchiveOnPrClose": true,
    "epitaxyPrefs": {
      "starred-local-code-sessions": [
        "local_a12e77b7-0706-4b3e-a0cf-ccab1fe67999"
      ],
      "starred-cowork-spaces": [
        "4863641e-9744-42d6-9489-869fa9300635"
      ],
      "starred-session-groups": [],
      "dframe-local-slice": {
        "pinnedOrder": [
          "code:local_a12e77b7-0706-4b3e-a0cf-ccab1fe67999",
          "cowork:local_750b39d2-46dd-48da-b5cf-5794a1b83fa5",
          "cowork:local_ef6385cb-78e6-4340-8860-613f93dc1c79",
          "cowork-artifact:today-attention",
          "cowork-space:4863641e-9744-42d6-9489-869fa9300635",
          "cowork-artifact:ds-productivity-dashboard",
          "cowork-artifact:agent-fleet-tracker",
          "cowork:local_40bd802f-72a4-41fa-b857-871137e2b394",
          "cowork:local_d7e7cd39-7c2a-459e-b852-756984c33274",
          "cowork:local_d7250405-aad0-4e19-a0fd-2d44137aebf6",
          "cowork:local_808a6413-ca65-4de9-81bb-3c9a47ac30c5"
        ],
        "homeProjectsPinnedOrder": []
      },
      "desktop-frame.paneStore.v1": {
        "state": {
          "extraPanesByMode": {},
          "colWeightsByMode": {},
          "rowSplit": 0.5,
          "draftNonce": 0
        },
        "version": 4
      },
      "ccd-sessions-filter": {
        "state": {
          "selectedProjects": []
        },
        "version": 0
      },
      "epitaxy-transcript-links-in-preview": false,
      "epitaxy-transcript-links-chooser-seen": true,
      "dframe-group-scopes": {
        "8b39e467-f7fd-42a9-be9b-a6fa6abd9a15/299f6d80-caaa-48d8-9451-9bf8b0c731e9": {
          "groups": [
            {
              "id": "cg-90c6885c-d324-4993-a276-f6e7ee721ded",
              "name": "Wren"
            }
          ],
          "assignments": {
            "code:local_3caccd8f-c4e4-46d0-9f36-2401eeb38f3f": "cg-90c6885c-d324-4993-a276-f6e7ee721ded",
            "code:local_b3117ae0-cb4f-496d-b098-e279a9bf257b": "cg-90c6885c-d324-4993-a276-f6e7ee721ded",
            "code:local_f35da168-a62a-4cd0-a450-8adabb48b49d": "cg-90c6885c-d324-4993-a276-f6e7ee721ded",
            "code:local_f9ed308c-c6d1-46f5-80fb-a0e91aecfe20": "cg-90c6885c-d324-4993-a276-f6e7ee721ded",
            "code:local_ed833c73-972c-4592-9d44-2743dbca82af": "cg-90c6885c-d324-4993-a276-f6e7ee721ded"
          },
          "order": {
            "cg-90c6885c-d324-4993-a276-f6e7ee721ded": [
              "code:local_ed833c73-972c-4592-9d44-2743dbca82af",
              "code:local_f9ed308c-c6d1-46f5-80fb-a0e91aecfe20",
              "code:local_f35da168-a62a-4cd0-a450-8adabb48b49d",
              "code:local_b3117ae0-cb4f-496d-b098-e279a9bf257b",
              "code:local_3caccd8f-c4e4-46d0-9f36-2401eeb38f3f"
            ]
          }
        }
      },
      "cc-landing-worktree-enabled": false
    }
  }
}
