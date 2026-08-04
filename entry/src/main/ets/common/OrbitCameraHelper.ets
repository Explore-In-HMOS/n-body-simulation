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

import { angleAxis, distanceVec3, normalizeQuat, quatMultQuat, quatMultVec3 } from './VectorMath';
import { Quaternion, Vec3 } from '@kit.ArkGraphics3D';

class OrbitCameraHelper {
  private orbitDistance_: number = 3.0;
  private cameraTargetPosition_: Vec3 = { x: 0, y: 0, z: 0 };
  private cameraRotation_: Quaternion = {
    x: 0,
    y: 0,
    z: 0,
    w: 1
  };
  private x_: number = 0;
  private y_: number = 0;
  private deltaX_: number = 0;
  private deltaY_: number = 0;
  private pinchDistance_: number | undefined = undefined;
  private state: number = -1; // 0 press, 1 pinch

  SetOrbitFromTarget(targetPosition: Vec3, rotation: Quaternion, orbitDistance: number): void {
    this.orbitDistance_ = orbitDistance;
    this.cameraRotation_ = rotation;
    this.cameraTargetPosition_ = targetPosition;
  }

  SetOrbitFromEyeWithDistance(eyePosition: Vec3, rotation: Quaternion, orbitDistance: number): void {
    this.orbitDistance_ = orbitDistance;
    this.cameraRotation_ = rotation;
    const toTargetVec = quatMultVec3(this.cameraRotation_, { x: 0.0, y: 0.0, z: -orbitDistance });
    this.cameraTargetPosition_ = {
      x: eyePosition.x + toTargetVec.x,
      y: eyePosition.y + toTargetVec.y,
      z: eyePosition.z + toTargetVec.z
    };
  }

  SetOrbitFromEye(eyePosition: Vec3, targetPosition: Vec3, rotation: Quaternion): void {
    this.orbitDistance_ = distanceVec3(eyePosition, targetPosition);
    this.cameraRotation_ = rotation;
    const toTargetVec = quatMultVec3(this.cameraRotation_, { x: 0.0, y: 0.0, z: -this.orbitDistance_ });
    this.cameraTargetPosition_ = {
      x: eyePosition.x + toTargetVec.x,
      y: eyePosition.y + toTargetVec.y,
      z: eyePosition.z + toTargetVec.z
    };
  }

  GetCameraPosition(): Vec3 {
    const ret = quatMultVec3(this.cameraRotation_, { x: 0.0, y: 0.0, z: this.orbitDistance_ });
    return {
      x: ret.x + this.cameraTargetPosition_.x,
      y: ret.y + this.cameraTargetPosition_.y,
      z: ret.z + this.cameraTargetPosition_.z
    };
  }

  GetCameraRotation(): Quaternion {
    return this.cameraRotation_;
  }

  OnPress(event: TouchEvent): void {
    if (event.touches.length === 1) {
      this.x_ = event.touches[0].x;
      this.y_ = event.touches[0].y;
      this.state = 0;
    }
  }

  OnRelease(event: TouchEvent): void {
    this.x_ = 0;
    this.y_ = 0;
    this.deltaX_ = 0;
    this.deltaY_ = 0;
    this.state = -1;
  }

  UpdateCameraRotation(dx: number, dy: number): void {
    const rotationX: Quaternion = angleAxis(dx, { x: 0.0, y: -1.0, z: 0.0 });
    const rotationY: Quaternion = angleAxis(dy, quatMultVec3(this.cameraRotation_,
      { x: -1.0, y: 0.0, z: 0.0 }));
    this.cameraRotation_ = normalizeQuat(quatMultQuat(quatMultQuat(rotationX, rotationY), this.cameraRotation_));
  }

  UpdateCameraTargetPosition(dx: number, dy: number): void {
    const dirX = quatMultVec3(this.cameraRotation_, { x: 1.0, y: 0.0, z: 0.0 });
    const dirY = quatMultVec3(this.cameraRotation_, { x: 0.0, y: -1.0, z: 0.0 });
    this.cameraTargetPosition_.x += dirX.x * dx + dirY.x * dy;
    this.cameraTargetPosition_.y += dirX.y * dx + dirY.y * dy;
    this.cameraTargetPosition_.z += dirX.z * dx + dirY.z * dy;
  }

  OnMove(event: TouchEvent): void {
    if (event.touches.length === 1 && this.state === 0) {
      const sensitivity: number = 0.01;
      this.deltaX_ = event.touches[0].x - this.x_;
      this.deltaY_ = event.touches[0].y - this.y_;
      this.x_ = event.touches[0].x;
      this.y_ = event.touches[0].y;
      this.UpdateCameraRotation(sensitivity * this.deltaX_, sensitivity * this.deltaY_);
    }
  }

  HandleTouchEvent(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.OnPress(event);
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.OnRelease(event);
    }
    if (event.type === TouchType.Move) {
      this.OnMove(event);
    }
  }

  // pinch such a dizzy, better use touch event
  HandlePinchGestureActionUpdate(event: GestureEvent): void {
    if (!this.pinchDistance_) {
      this.pinchDistance_ = this.orbitDistance_;
    }
    let scale = event.scale;
    if (scale === 0) {
      scale = 0.01;
    }
    this.orbitDistance_ = this.pinchDistance_ * (1 / scale);
    this.state = 1;
  }

  HandlePinchGestureActionEnd(): void {
    this.pinchDistance_ = undefined;
    this.state = 1;
  }

  HandlePanGestureActionUpdate(event: GestureEvent, flag: number): void {
    const sensitivity: number = 0.01;
    this.deltaX_ = event.offsetX - this.x_;
    this.deltaY_ = event.offsetY - this.y_;
    if (flag === 0) {
      // rotation
      this.UpdateCameraRotation(sensitivity * this.deltaX_, sensitivity * this.deltaY_);
    } else if (flag === 1) {
      // translation
      this.UpdateCameraTargetPosition(-sensitivity * this.deltaX_, -sensitivity * this.deltaY_);
    }
    this.x_ = event.offsetX;
    this.y_ = event.offsetY;
  }

  HandlePanGestureActionEnd(): void {
    this.deltaX_ = 0;
    this.deltaY_ = 0;
    this.x_ = 0;
    this.y_ = 0;
  }
}

export { OrbitCameraHelper };