import test from "node:test";
import assert from "node:assert/strict";
import { createHmac, timingSafeEqual } from "node:crypto";
import { inflateSync } from "node:zlib";
import { buildAgoraRtcToken } from "../src/index.js";

const APP_ID = "0123456789abcdef0123456789abcdef";
const CERTIFICATE = "abcdef0123456789abcdef0123456789";

function hmac(key, message) {
  return createHmac("sha256", key).update(message).digest();
}

function readString(buffer, cursor) {
  const length = buffer.readUInt16LE(cursor.offset);
  cursor.offset += 2;
  const value = buffer.subarray(cursor.offset, cursor.offset + length);
  cursor.offset += length;
  return value;
}

test("Agora AccessToken2 uses verifiable HMAC-SHA256 and RTC privileges", async () => {
  const token = await buildAgoraRtcToken({
    appId: APP_ID,
    appCertificate: CERTIFICATE,
    channelName: "dvx_party_0123456789abcdef01234567",
    account: "10000001",
    expireSeconds: 3600,
  });

  assert.match(token, /^007[A-Za-z0-9+/]+=*$/);
  const packed = inflateSync(Buffer.from(token.slice(3), "base64"));
  const cursor = { offset: 0 };
  const signature = readString(packed, cursor);
  const signingInfo = packed.subarray(cursor.offset);

  const info = { offset: 0 };
  const appId = readString(signingInfo, info).toString("utf8");
  const issueTs = signingInfo.readUInt32LE(info.offset);
  info.offset += 4;
  const tokenExpiry = signingInfo.readUInt32LE(info.offset);
  info.offset += 4;
  const salt = signingInfo.readUInt32LE(info.offset);
  info.offset += 4;
  const serviceCount = signingInfo.readUInt16LE(info.offset);
  info.offset += 2;

  assert.equal(appId, APP_ID);
  assert.equal(tokenExpiry, 3600);
  assert.equal(serviceCount, 1);

  const serviceType = signingInfo.readUInt16LE(info.offset);
  info.offset += 2;
  const privilegeCount = signingInfo.readUInt16LE(info.offset);
  info.offset += 2;
  assert.equal(serviceType, 1);
  assert.equal(privilegeCount, 4);

  const privilegeIds = [];
  for (let i = 0; i < privilegeCount; i++) {
    privilegeIds.push(signingInfo.readUInt16LE(info.offset));
    info.offset += 2;
    assert.equal(signingInfo.readUInt32LE(info.offset), 3600);
    info.offset += 4;
  }
  assert.deepEqual(privilegeIds, [1, 2, 3, 4]);

  assert.equal(readString(signingInfo, info).toString("utf8"), "dvx_party_0123456789abcdef01234567");
  assert.equal(readString(signingInfo, info).toString("utf8"), "10000001");
  assert.equal(info.offset, signingInfo.length);

  const issueBytes = Buffer.alloc(4);
  issueBytes.writeUInt32LE(issueTs);
  const saltBytes = Buffer.alloc(4);
  saltBytes.writeUInt32LE(salt);
  const signingKey1 = hmac(Buffer.from(CERTIFICATE), issueBytes);
  const signingKey2 = hmac(signingKey1, saltBytes);
  const expectedSignature = hmac(signingKey2, signingInfo);
  assert.equal(signature.length, expectedSignature.length);
  assert.ok(timingSafeEqual(signature, expectedSignature));
});

test("Agora token builder rejects invalid app credentials", async () => {
  await assert.rejects(
    buildAgoraRtcToken({
      appId: "not-an-app-id",
      appCertificate: CERTIFICATE,
      channelName: "dvx_party_test",
      account: "10000001",
    }),
    /agora_credentials_invalid/,
  );
});
