import { LifecycleEntry } from '../../data/models/GameRepositoryTypes';

@Component
export struct LifecycleRow {
  entry: LifecycleEntry = { capturedAt: 0, stage: '', message: '' };

  private formatTime(value: number): string {
    const date = new Date(value);
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      Row() {
        Text(this.entry.stage).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#8B3A62')
        Text(this.formatTime(this.entry.capturedAt)).fontSize(11).fontColor('#7A3654').opacity(0.65)
      }.width('100%').justifyContent(FlexAlign.SpaceBetween)

      Text(this.entry.message)
        .fontSize(13)
        .fontColor('#7A3654')
        .margin({ top: 4 })
        .width('100%')
    }
    .padding(10)
    .width('100%')
    .borderRadius(12)
    .backgroundColor('#FFF7FB')
  }
}
