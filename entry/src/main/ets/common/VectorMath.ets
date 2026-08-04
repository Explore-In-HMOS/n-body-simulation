/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { Node, Quaternion, Vec3 } from '@kit.ArkGraphics3D';

const zeroVector: Vec3 = {x: 0, y:0, z: 0}
const identityQuaternion: Quaternion = {x: 0, y:0, z: 0, w: 1}

function add(l: Vec3, r: Vec3): Vec3 {
  return { x: l.x + r.x, y: l.y + r.y, z: l.z + r.z };
}

function sub(l: Vec3, r: Vec3): Vec3 {
  return { x: l.x - r.x, y: l.y - r.y, z: l.z - r.z };
}

function dot(l: Vec3, r: Vec3): number {
  return l.x * r.x + l.y * r.y + r.z * l.z;
}

function scalarMul(l: Vec3, n: number): Vec3 {
  return { x: l.x * n, y: l.y * n, z: l.z * n };
}

function normalize(l: Vec3): Vec3 {
  const d = Math.sqrt(dot(l, l));
  return { x: l.x / d, y: l.y / d, z: l.z / d };
}

function normalizeQuaternion(q: Quaternion): Quaternion {
  const len = lengthQuaternion(q);

  if (len < 1e-9) {
    return {x: 0, y:0, z: 0, w: 1};
  }

  return {
    x: q.x / len,
    y: q.y / len,
    z: q.z / len,
    w: q.w / len
  }
}

function cross(l: Vec3, r: Vec3): Vec3 {

  return { x: (l.y * r.z - l.z * r.y), y: (l.z * r.x - l.x * r.z), z: (l.x * r.y - l.y * r.x) };
}

function mul(l: Quaternion, d: number): Quaternion {
  return {
    x: l.x * d,
    y: l.y * d,
    z: l.z * d,
    w: l.w * d
  };
}

function lookAt(node: Node, eye: Vec3, center: Vec3, up: Vec3) {

  let t: number;

  let q: Quaternion = {
    x: 0.0,
    y: 0.0,
    z: 0.0,
    w: 0.0
  };
  const f = normalize(sub(center, eye));
  const m0 = normalize(cross(f, up));
  const m1 = cross(m0, f);
  const m2: Vec3 = { x: -f.x, y: -f.y, z: -f.z };
  if (m2.z < 0) {
    if (m0.x > m1.y) {
      t = 1.0 + m0.x - m1.y - m2.z;
      q = {
        x: t,
        y: m0.y + m1.x,
        z: m2.x + m0.z,
        w: m1.z - m2.y
      };
    } else {
      t = 1.0 - m0.x + m1.y - m2.z;
      q = {
        x: m0.y + m1.x,
        y: t,
        z: m1.z + m2.y,
        w: m2.x - m0.z
      };
    }
  } else {
    if (m0.x < -m1.y) {
      t = 1.0 - m0.x - m1.y + m2.z;
      q = {
        x: m2.x + m0.z,
        y: m1.z + m2.y,
        z: t,
        w: m0.y - m1.x
      };
    } else {
      t = 1.0 + m0.x + m1.y + m2.z;
      q = {
        x: m1.z - m2.y,
        y: m2.x - m0.z,
        z: m0.y - m1.x,
        w: t
      };
    }
  }
  node.position = eye;
  node.rotation = mul(q, 0.5 / Math.sqrt(t));
}

/** Get length */
function lengthQuaternion(quat: Quaternion): number {
  return Math.sqrt(quat.x * quat.x + quat.y * quat.y + quat.z * quat.z + quat.w * quat.w);
}

function lengthVec3(v: Vec3): number {
  return Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

function magnitudeVec3(vec: Vec3): number {
  return Math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z);
}

function magnitudeSquareVec3(vec: Vec3): number {
  return vec.x * vec.x + vec.y * vec.y + vec.z * vec.z;
}

/** Return distance between vector2's */
function distanceVec3(v0: Vec3, v1: Vec3): number {
  const v: Vec3 = { x: v0.x - v1.x, y: v0.y - v1.y, z: v0.z - v1.z };
  return magnitudeVec3(v);
}

/** Creates a rotation which rotates angle degrees around axis, takes in angle as radians */
function angleAxis(angle: number, axis: Vec3): Quaternion {
  const sinHalfAngle: number = Math.sin(angle * 0.5);
  const axisMultiplied: Vec3 = { x: axis.x * sinHalfAngle, y: axis.y * sinHalfAngle, z: axis.z * sinHalfAngle };
  const ret: Quaternion = {
    x: axisMultiplied.x,
    y: axisMultiplied.y,
    z: axisMultiplied.z,
    w: Math.cos(angle * 0.5)
  };
  return ret;
}

/** Multiply vector3 by quaternion(rotation) */
function quatMultVec3(q: Quaternion, v: Vec3): Vec3 {
  const quatvector: Vec3 = { x: q.x, y: q.y, z: q.z };

  const uv: Vec3 = cross(quatvector, v);
  const uuv: Vec3 = (cross(quatvector, uv));
  const ret: Vec3 = {
    x: v.x + (uv.x * q.w + uuv.x) * 2,
    y: v.y + (uv.y * q.w + uuv.y) * 2,
    z: v.z + (uv.z * q.w + uuv.z) * 2
  };
  return ret;
}

function quatMultQuat(q0: Quaternion, q1: Quaternion): Quaternion {
  const ret: Quaternion = {
    x: q0.w * q1.x + q0.x * q1.w + q0.y * q1.z - q0.z * q1.y,
    y: q0.w * q1.y + q0.y * q1.w + q0.z * q1.x - q0.x * q1.z,
    z: q0.w * q1.z + q0.z * q1.w + q0.x * q1.y - q0.y * q1.x,
    w: q0.w * q1.w - q0.x * q1.x - q0.y * q1.y - q0.z * q1.z
  };
  return ret;
}

/** Normalizes quaternion */
function normalizeQuat(q: Quaternion): Quaternion {
  const len: number = lengthQuaternion(q);
  if (len <= 0.0) {
    return {
      x: 0.0,
      y: 0.0,
      z: 0.0,
      w: 1.0
    };
  }
  const oneOverLen: number = 1.0 / len;
  return {
    x: q.x * oneOverLen,
    y: q.y * oneOverLen,
    z: q.z * oneOverLen,
    w: q.w * oneOverLen
  };
}

function quaternionFromTo(a: Vec3, b: Vec3): Quaternion{
  const d = dot(a, b);
  
  if (d > 0.999999) {
    return {x: 0, y:0, z: 0, w: 1};
  }

  if (d < -0.999999) {
    let axis = cross({x: 1, y: 0, z: 0}, a);
    if (lengthVec3(axis) < 1e-6) {
      axis = cross({x: 0, y: 1, z: 0}, a);
    }
    return quaternionFromAxisAngle(normalize(axis), Math.PI);
  }
  const axis = cross(a, b);
  const w = 1 + d;
  return normalizeQuaternion({ x: axis.x, y: axis.y, z: axis.z, w: w });
}

function quaternionFromAxisAngle(axis: Vec3, angle: number): Quaternion {
  const halfAngle = angle * 0.5;
  const s = Math.sin(halfAngle);

  return {
    x: axis.x * s,
    y: axis.y * s,
    z: axis.z * s,
    w: Math.cos(halfAngle)
  }
}

export {
  zeroVector,
  add,
  sub,
  dot,
  normalize,
  mul,
  cross,
  lookAt,
  lengthVec3,
  magnitudeVec3,
  distanceVec3,
  angleAxis,
  quatMultVec3,
  quatMultQuat,
  normalizeQuat,
  magnitudeSquareVec3,
  scalarMul,
  quaternionFromTo};