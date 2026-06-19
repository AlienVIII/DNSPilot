import assert from "node:assert/strict";
import { test } from "node:test";

import { buildApplyPlanRequest } from "./benchmark-guidance.js";

test("apply-plan request uses benchmark recommendation and matching resolver", () => {
  const request = buildApplyPlanRequest({
    platform: "android-play",
    profiles: [
      {
        id: "cloudflare",
        name: "Cloudflare",
        protocol: "plain",
        ipv4_servers: ["1.1.1.1", "1.0.0.1"],
      },
      {
        id: "quad9",
        name: "Quad9",
        protocol: "plain",
        ipv4_servers: ["9.9.9.9"],
      },
    ],
    result: {
      data: {
        summary: {
          health: "healthy",
          recommended_profile_id: "quad9",
        },
        runs: [
          { profile_id: "cloudflare", resolver: "1.1.1.1:53" },
          { profile_id: "quad9", resolver: "9.9.9.9:53" },
        ],
        recommendation: {
          profile_id: "quad9",
          confidence: "high",
        },
      },
    },
  });

  assert.deepEqual(request, {
    platform: "android-play",
    profileId: "quad9",
    profileName: "Quad9",
    testedResolver: "9.9.9.9:53",
    confidence: "high",
    gateHealth: "healthy",
    environment: {
      vpnActive: false,
      mdmProfileActive: false,
      corporateDnsDetected: false,
      captivePortalDetected: false,
    },
  });
});

test("apply-plan request falls back to profile server when runs are absent", () => {
  const request = buildApplyPlanRequest({
    platform: "ios",
    profiles: [
      {
        id: "cloudflare",
        name: "Cloudflare",
        protocol: "plain",
        ipv4_servers: ["1.1.1.1"],
      },
    ],
    result: {
      data: {
        summary: {
          health: "degraded",
          recommended_profile_id: "cloudflare",
        },
        recommendation: {
          profile_id: "cloudflare",
          confidence: "medium",
        },
      },
    },
    environment: {
      vpnActive: true,
    },
  });

  assert.equal(request.profileId, "cloudflare");
  assert.equal(request.profileName, "Cloudflare");
  assert.equal(request.testedResolver, "1.1.1.1");
  assert.equal(request.confidence, "medium");
  assert.equal(request.gateHealth, "degraded");
  assert.equal(request.environment.vpnActive, true);
});

test("apply-plan request is unavailable when benchmark has no recommendation", () => {
  const request = buildApplyPlanRequest({
    platform: "ios",
    profiles: [],
    result: {
      data: {
        summary: {
          health: "failed",
          recommended_profile_id: null,
        },
        recommendation: null,
      },
    },
  });

  assert.equal(request, null);
});
