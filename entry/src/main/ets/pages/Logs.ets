import { LifecycleRow } from '../common/components/LifecycleRow';
import PageRoutes from '../common/constants/PageRoutes';
import PageRouteTracker from '../common/util/PageRouteTracker';
import LifecycleLog from '../common/util/LifecycleLog';
import { LifecycleEntry } from '../data/models/GameRepositoryTypes';

@Component
export struct Logs {
  @State entries: LifecycleEntry[] = [];

  onPageShow() {
    PageRouteTracker.setCurrentPage(PageRoutes.LOGS);
    this.entries = LifecycleLog.getAll().slice().reverse();
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Text('Logs')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#B31252')
          Text('Lifecycle events')
            .fontSize(12)
            .fontColor('#7A3654')
            .opacity(0.75)
            .margin({ top: 2, bottom: 8 })
          if (this.entries.length === 0) {
            Text('No lifecycle events yet.')
              .fontSize(14)
              .fontColor('#7A3654')
              .textAlign(TextAlign.Center)
              .width('100%')
          } else {
            ForEach(this.entries, (entry: LifecycleEntry) => {
              LifecycleRow({ entry: entry }).margin({ bottom: 8 })
            }, (entry: LifecycleEntry) => `${entry.capturedAt}-${entry.stage}`)
          }
        }
        .width('100%')
        .padding({ bottom: 16 })
      }
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#FFE6F2')
  }
}
