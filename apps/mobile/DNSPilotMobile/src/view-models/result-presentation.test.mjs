import assert from "node:assert/strict";
import { test } from "node:test";

import { createTranslator } from "./localization.js";
import { presentAction, presentHealth, presentNote, presentProcessReason, presentResolverDiagnosis, presentResolverStatus } from "./result-presentation.js";

test("presents known benchmark values in Vietnamese without changing unknown Core details", () => {
  const t = createTranslator("vi");

  assert.equal(presentHealth("healthy", t), "Tốt");
  assert.equal(presentResolverStatus("success", t), "OK");
  assert.equal(presentResolverDiagnosis("Measured successfully.", t), "Đo thành công.");
  assert.equal(presentAction("compare", t), "So sánh DNS");
  assert.equal(presentNote("Best DNS lookup estimate for FastestRawDns mode.", t), "Ước lượng kết quả DNS nhanh nhất của lần đo này.");
  assert.equal(presentNote("Recommended profile: google-public-dns.", t), "Profile đề xuất: google-public-dns.");
  assert.equal(presentProcessReason("Completed without a recommendation.", t), "Hoàn tất nhưng chưa có đề xuất phù hợp.");
  assert.equal(presentProcessReason("Recommended profile: google-public-dns.", t), "Profile đề xuất: google-public-dns.");
  assert.equal(
    presentNote("This estimates DNS lookup behavior, not TCP, TLS, HTTP, QUIC, browser cache, VPN, MDM, captive portal, or app-specific behavior.", t),
    "Chỉ ước lượng DNS lookup; không đo TCP, TLS, HTTP, QUIC, cache trình duyệt, VPN, MDM, captive portal hoặc hành vi riêng của app."
  );
  assert.equal(presentNote("Unrecognized Core detail.", t), "Unrecognized Core detail.");
});
