@Component
export struct AchievementBadge {
  title: string = '';
  description: string = '';
  unlocked: boolean = false;

  build() {
    Column() {
      Text(this.title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.unlocked ? '#2C6E49' : '#8B3A62')

      Text(this.description)
        .fontSize(11)
        .fontColor(this.unlocked ? '#3A6B52' : '#7A3654')
        .opacity(0.7)
        .margin({ top: 2 })
    }
    .width('100%')
    .padding(10)
    .borderRadius(10)
    .backgroundColor(this.unlocked ? '#EAF8EE' : '#FFF7FB')
  }
}
