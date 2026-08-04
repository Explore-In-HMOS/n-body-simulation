import { Geometry, Position3, Vec3 } from '@kit.ArkGraphics3D'
import { add, magnitudeSquareVec3, normalize, scalarMul, sub, zeroVector } from './VectorMath';

const G: number = 1; // gravitational constant, normally its value is 6.6743 × 10^-11 m^3 kg^-1 s^-2

interface BodyParameters {
  mass: number;
  initialPosition: Position3,
  initialVelocity: Vec3,
  rotationSpeed: number,
  radius: number,
  imageReference: string,
  focusable: boolean
}

class Body {
  public static bodies: Body[] = [];
  private static heavyBodyIndexes: number[] = [];
  private static idCounter: number = 0;
  private id: number;
  private geometry: Geometry;
  private position: Position3 = zeroVector;
  private velocity: Vec3;
  private rotationAngle: number;
  private rotationSpeed: number;
  private mass: number;
  private totalAcceleration: Vec3 = zeroVector;
  private oldTotalAcceleration: Vec3 = zeroVector;
  public focusable: boolean = false;
  private static focusedObject: Body | undefined = undefined;
  private static massThreshold: number = 0.02;

  constructor(geometry: Geometry, initialPosition: Position3, initialVelocity: Vec3, rotationSpeed: number,
    mass: number, focusable: boolean) {
    this.id = Body.idCounter;
    Body.idCounter++;

    this.geometry = geometry;
    this.setPosition(initialPosition);
    this.velocity = initialVelocity
    this.rotationAngle = 0;
    this.rotationSpeed = rotationSpeed;
    this.mass = mass;
    this.focusable = focusable;

    Body.bodies.push(this);

    if (this.mass >= Body.massThreshold) {
      Body.heavyBodyIndexes.push(this.id);
    }

    if (!Body.focusedObject) {
      Body.focusedObject = this;
    }
  }

  /*
   * If mass is lower than threshold mass, do not apply gravitational force towards other objects.
   * */
  public static setMassThreshold(mass: number) {
    Body.massThreshold = mass;
  }

  public static setFocus(obj: Body) {
    Body.focusedObject = obj;
  }

  private getRelativePosition(pos: Vec3) {
    if (Body.focusedObject === undefined) {
      return pos;
    }
    const relative = sub(pos, Body.focusedObject.position);
    //return quatMultVec3(Body.Q, relative);
    return relative;
  }

  public setPosition(position: Position3) {
    this.position = position;
    this.geometry.position = this.getRelativePosition(this.position);
  }

  public updatePositions(deltaTime: number) {
    // Verlet
    // x_new = x + v*dt + 0.5*a_old*dt^2
    const newPosition: Vec3 = add(this.position,
      add(scalarMul(this.velocity, deltaTime), scalarMul(this.oldTotalAcceleration, 0.5 * deltaTime * deltaTime)))
    this.setPosition(newPosition);
  }

  public updateRotation(deltaTime: number) {
    // Build a quaternion for rotation around the Y axis
    this.rotationAngle = (this.rotationAngle + deltaTime * this.rotationSpeed) % (2 * Math.PI);
    const halfAngle = this.rotationAngle / 2;
    this.geometry.rotation = {
      x: 0,
      y: Math.sin(halfAngle),
      z: 0,
      w: Math.cos(halfAngle)
    };
  }

  public updateVelocities(deltaTime: number) {
    // Verlet
    // v_new = v + 0.5*(a_old + a_new)*dt
    this.velocity =
      add(this.velocity, scalarMul(add(this.totalAcceleration, this.oldTotalAcceleration), 0.5 * deltaTime))
  }

  public calculateTotalAccelerationApplyingToObject() {
    let totalAcc: Vec3 = zeroVector;
    this.oldTotalAcceleration = this.totalAcceleration;

    Body.heavyBodyIndexes.forEach((value: number) => {
      const body: Body = Body.bodies[value];
      if (body.id === this.id) {
        return;
      }

      const positionDiff: Vec3 = sub(body.position, this.position);
      const distanceSquare = magnitudeSquareVec3(positionDiff);
      const acc: Vec3 = scalarMul(normalize(positionDiff), G * body.mass / distanceSquare);
      totalAcc = add(totalAcc, acc);
    })

    this.totalAcceleration = totalAcc;
  }
}

export { Body, BodyParameters };