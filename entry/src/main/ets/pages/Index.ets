// Splash screen, it navigates directly to ScenePage

@Entry
@Component
struct Index {
  @Provide pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.pathStack.pushPathByName('SimulationPage', null);
  }

  build() {
    Navigation(this.pathStack) {
      Column({ space: 12 }) {
        Text('Loading...')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Grey)
      .justifyContent(FlexAlign.Center)
    }
    .hideTitleBar(true)
  }
}