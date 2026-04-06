@Component
export struct StatCard {
  label: string = '';
  value: string = '';
  hint: string = '';

  build() {
    Column() {
      Text(this.label)
        .fontSize(12)
        .fontColor('#8B3A62')
        .opacity(0.7)

      Text(this.value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#B31252')
        .margin({ top: 4 })

      if (this.hint) {
        Text(this.hint)
          .fontSize(11)
          .fontColor('#7A3654')
          .opacity(0.65)
          .margin({ top: 2 })
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor('#FFF7FB')
  }
}
