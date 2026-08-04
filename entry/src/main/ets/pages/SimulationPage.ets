import {
  Camera,
  Environment,
  EnvironmentBackgroundType,
  Geometry,
  Image,
  MaterialType,
  MeshResource,
  PostProcessSettings,
  Scene,
  SceneResourceFactory,
  SceneResourceParameters,
  ShaderMaterial,
  SphereGeometry,
  ToneMappingType
} from '@kit.ArkGraphics3D';
import { OrbitCameraHelper } from '../common/OrbitCameraHelper';
import { lookAt } from '../common/VectorMath';
import { Body, BodyParameters } from '../common/Body';
import { taskpool } from '@kit.ArkTS';

function createImagePromise(globalScene: Scene | null, path: ResourceStr): Promise<Image> {
  return new Promise((resolve, reject) => {
    // Ensure the scene is loaded before accessing sceneFactory
    if (globalScene) {
      const sceneFactory: SceneResourceFactory = globalScene.getResourceFactory();
      const sceneImageParameter: SceneResourceParameters = {
        name: 'image',
        uri: path
      };

      const image: Promise<Image> = sceneFactory.createImage(sceneImageParameter);
      image.then((imageEntity: Image) => {
        resolve(imageEntity);
      }).catch((err: string) => {
        console.error(`Image load failed: ${err}.`);
        reject(err);
      });
    } else {
      reject('Scene is not loaded yet.');
    }
  });
}

@Builder
export function SimulationPageBuilder() {
  SimulationPage();
}

@Component
struct SimulationPage {
  @Consume pathStack: NavPathStack;
  scene: Scene | null = null;
  @State sceneOpt: SceneOptions | null = null;
  cam: Camera | null = null;
  orbitCamera: OrbitCameraHelper = new OrbitCameraHelper();
  // simulation speed
  readonly oneOverFPS: number = 1 / 30;
  simulationSpeedCoef: number = 0.2;
  speeds: number[] = [0.25, 0.5, 1, 2, 4]
  @State speedIndex: number = 2;

  bodyParams: BodyParameters[] =
    [
      {
        mass: 100,
        initialPosition: { x: 0, y: 0, z: 0 },
        initialVelocity: { x: 0, y: -0.06929, z: 0 },
        rotationSpeed: 0,
        radius: 2,
        imageReference: 'sun',
        focusable: true
      }, // sun
      {
        mass: 3,
        initialPosition: { x: 20, y: 0, z: 0 },
        initialVelocity: { x: 0, y: 2.2694, z: 0 },
        rotationSpeed: 0.02,
        radius: 0.5,
        imageReference: 'earth',
        focusable: true
      }, // earth
      {
        mass: 0.03,
        initialPosition: { x: 21, y: 0, z: 0 },
        initialVelocity: { x: 0, y: 4.0101, z: 0 },
        rotationSpeed: 0.01,
        radius: 0.2,
        imageReference: 'moon',
        focusable: false
      }, // moon
      {
        mass: 0.01,
        initialPosition: { x: -24, y: 0, z: 0 },
        initialVelocity: { x: 0, y: -2.415, z: 0 },
        rotationSpeed: 0,
        radius: 0.3,
        imageReference: 'mercury',
        focusable: true
      }, // comet
      {
        mass: 2.45,
        initialPosition: { x: -13.58796, y: 4.94561, z: 0 },
        initialVelocity: { x: -0.91038, y: -2.50125, z: 0 },
        rotationSpeed: -0.0005,
        radius: 0.48,
        imageReference: 'venus',
        focusable: true
      }, // venus
    ]
  focusedObjectIndex: number = 1;
  imageMats: Map<string, ShaderMaterial> = new Map<string, ShaderMaterial>();
  materialPaths: Map<string, Resource> = new Map<string, Resource>();

  aboutToAppear(): void {

    this.materialPaths.set('venus', $rawfile('Planets/venus.jpg'))
    this.materialPaths.set('earth', $rawfile('Planets/earth.jpg'))
    this.materialPaths.set('mercury', $rawfile('Planets/mercury.jpg'))
    this.materialPaths.set('moon', $rawfile('Planets/moon.jpg'))
    this.materialPaths.set('sun', $rawfile('Planets/sun.jpg'))

    this.Init();
    setInterval(async () => {
      if (this.scene) {
        const deltaTime: number = this.oneOverFPS * this.simulationSpeedCoef * this.speeds[this.speedIndex];
        console.info('[NBody] Update called');

        Body.bodies.forEach((body: Body) => {
          body.updatePositions(deltaTime);
          body.updateRotation(deltaTime);
        })
        Body.bodies.forEach((body: Body) => {
          body.calculateTotalAccelerationApplyingToObject();
        })
        Body.bodies.forEach((body: Body) => {
          body.updateVelocities(deltaTime);
        })
      }
    }, this.oneOverFPS);
  }

  aboutToDisappear(): void {
    if (this.scene) {
      this.scene.destroy();
    }
    this.cam = null;
    this.scene = null;
  }

  toggleSpeed() {
    this.speedIndex = this.speedIndex + 1 >= this.speeds.length ? 0 : this.speedIndex + 1;
  }

  focusNext() {
    this.focusedObjectIndex = this.focusedObjectIndex + 1 >= Body.bodies.length ? 0 : this.focusedObjectIndex + 1;

    if (!Body.bodies[this.focusedObjectIndex].focusable) {
      this.focusNext();
    } else {
      Body.setFocus(Body.bodies[this.focusedObjectIndex]);
    }
  }

  focusPrevious() {
    this.focusedObjectIndex = this.focusedObjectIndex - 1 < 0 ? Body.bodies.length - 1 : this.focusedObjectIndex - 1;

    if (!Body.bodies[this.focusedObjectIndex].focusable) {
      this.focusPrevious();
    } else {
      Body.setFocus(Body.bodies[this.focusedObjectIndex]);
    }
  }

  async createImageMats(rf: SceneResourceFactory, scene: Scene): Promise<boolean> {
    // create imageMats
    const entries = Array.from(this.materialPaths.entries());

    for (let index = 0; index < entries.length; index++) {
      const key = entries[index][0];
      const r = entries[index][1];
      let imageMat = await rf.createMaterial({ name: `imageMat_${key}` }, MaterialType.SHADER) as ShaderMaterial;

      // bind between shader and imageMat
      let createdImage = await createImagePromise(scene, r);
      if (createdImage && imageMat.colorShader) {
        imageMat.colorShader.inputs.BASE_COLOR_Image = createdImage;
      }
      this.imageMats.set(key, imageMat);
    }

    return true;
  }

  async createBodies(rf: SceneResourceFactory, scene: Scene) {
    this.bodyParams.forEach(async (params: BodyParameters, index: number) => {
      const sphereGeom: SphereGeometry = new SphereGeometry();
      sphereGeom.radius = params.radius;
      sphereGeom.segmentCount = 16;
      const sphereMeshRes: MeshResource = await rf.createMesh({ name: 'sphereMeshRes' }, sphereGeom);
      let geom: Geometry = await rf.createGeometry({ name: 'sphere' }, sphereMeshRes);

      geom.mesh.materialOverride = undefined;

      const mat: ShaderMaterial | undefined = this.imageMats.get(params.imageReference);
      if (mat) {
        geom.mesh.subMeshes[0].material = mat;
      }

      const body: Body =
        new Body(geom, params.initialPosition, params.initialVelocity, params.rotationSpeed, params.mass,
          params.focusable);

      if (index === this.focusedObjectIndex) {
        Body.setFocus(body);
      }
    })
  }

  createEnvironment(rf: SceneResourceFactory, scene: Scene) {
    // Environment
    let sceneImageParameter: SceneResourceParameters =
      { name: 'image', uri: $rawfile('Environment/2k_stars_milky_way.jpg') };
    let image: Promise<Image> = rf.createImage(sceneImageParameter);
    image.then(async (imageEntity: Image) => {
      // Create Environment
      let sceneEnvironmentParameter: SceneResourceParameters = { name: 'env' };
      let env: Promise<Environment> = rf.createEnvironment(sceneEnvironmentParameter);
      env.then(async (envEntity: Environment) => {
        envEntity.backgroundType = EnvironmentBackgroundType.BACKGROUND_EQUIRECTANGULAR;
        envEntity.environmentImage = imageEntity;
        // Set environment related properties
        envEntity.indirectDiffuseFactor.x = 1;
        envEntity.indirectDiffuseFactor.y = 1;
        envEntity.indirectDiffuseFactor.z = 1;
        envEntity.indirectDiffuseFactor.w = 1;

        if (this.scene) {
          this.scene.environment = envEntity;
        }
      }).catch((err: string) => {
        console.error(`Environment mapping material create failed: ${err}`);
      });
    }).catch((err: string) => {
      console.error(`Image load failed: ${err}`);
    });

    scene.environment.irradianceCoefficients =
      [{ x: 1.080343842506409, y: 0.936282396316528, z: 0.665518164634705 },
        { x: 0.959947884082794, y: 0.828918874263763, z: 0.569704353809357 },
        { x: 0.848236382007599, y: 0.715092182159424, z: 0.473145037889481 },
        { x: -0.591795265674591, y: -0.501678705215454, z: -0.334018945693970 },
        { x: -0.775423347949982, y: -0.655484378337860, z: -0.437325984239578 },
        { x: 1.053589701652527, y: 0.887459456920624, z: 0.587381422519684 },
        { x: -0.018954016268253, y: -0.014871496707201, z: -0.008891185745597 },
        { x: -0.566255271434784, y: -0.476870059967041, z: -0.314557582139969 },
        { x: -0.239390164613724, y: -0.200478553771973, z: -0.132790848612785 }
      ];
  }

  async createCamera(rf: SceneResourceFactory, scene: Scene) {
    // Create and set up the camera to view the scene and enable orbit control
    this.cam = await rf.createCamera({ 'name': 'camera' });
    this.cam.enabled = true;
    lookAt(this.cam, { x: 0, y: 1, z: -4 }, { x: 0, y: 0, z: 0 }, { x: 0, y: 2, z: 0 });
    this.sceneOpt = { scene: this.scene, modelType: ModelType.SURFACE } as SceneOptions;
    if (scene.root) {
      this.orbitCamera.SetOrbitFromEye(this.cam.position, scene.root.position, this.cam.rotation)
    } else {
      this.orbitCamera.SetOrbitFromEye(this.cam.position, { x: 0, y: 0, z: 0 }, this.cam.rotation)
    }
    // Enable tone mapping for better HDR visualization
    (this.cam.postProcess as PostProcessSettings) = {
      toneMapping: {
        type: ToneMappingType.ACES,
        exposure: 0.7
      }
    };
  }

  Init(): void {
    if (this.scene === null) {
      Scene.load()
        .then(async (scene: Scene) => {
          this.scene = scene;
          if (!this.scene.root) {
            return;
          }
          const rf: SceneResourceFactory = scene.getResourceFactory();

          let res = await this.createImageMats(rf, scene);

          if (res) {
            await this.createBodies(rf, scene);
          }
          this.createEnvironment(rf, scene);
          this.createCamera(rf, scene);
        });
    }

  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        if (this.sceneOpt) {

          // Present 3D scenes through Component3D
          Component3D(this.sceneOpt)
            .onTouch((event: TouchEvent) => {
              // Handle touch input for orbit camera rotation
              this.orbitCamera.HandleTouchEvent(event);
              if (this.cam) {
                this.cam.position = this.orbitCamera.GetCameraPosition();
                this.cam.rotation = this.orbitCamera.GetCameraRotation();
              }
            })
            .gesture(
              PinchGesture({ fingers: 2 })
                .onActionStart((event: GestureEvent) => {
                  console.info('Pinch start');
                })
                .onActionUpdate((event: GestureEvent) => {
                  // Handle pinch gesture for camera zoom
                  this.orbitCamera.HandlePinchGestureActionUpdate(event);
                  if (this.cam) {
                    this.cam.position = this.orbitCamera.GetCameraPosition();
                    this.cam.rotation = this.orbitCamera.GetCameraRotation();
                  }
                })
                .onActionEnd(() => {
                  this.orbitCamera.HandlePinchGestureActionEnd();
                }))
          Row() {
            Path()
              .commands('M0 30 L60 0 L60 60 Z')
              .fill(Color.White)
              .stroke(Color.Black)
              .strokeWidth(3)
              .onClick(() => {
                this.focusPrevious();
              })

            Button(`x${this.speeds[this.speedIndex]}`)
              .borderWidth(3)
              .borderColor(Color.Black)
              .backgroundColor(Color.White)
              .fontColor(Color.Black)
              .onClick(() => {
                this.toggleSpeed();
              })

            Path()
              .commands('M60 30 L0 60 L0 0 Z')
              .fill(Color.White)
              .stroke(Color.Black)
              .strokeWidth(3)
              .onClick(() => {
                this.focusNext();
              })
          }
        } else {
          Column() {
            Text('loading ...')
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height('100%')
        }
      }
      .width('100%')
      .height('100%');
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      return true; // to prevent swiping back
    })
  }
}