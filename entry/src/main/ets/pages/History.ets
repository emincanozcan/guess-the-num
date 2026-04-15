import { HistoryRow } from '../common/components/HistoryRow';
import PageRoutes from '../common/constants/PageRoutes';
import PageRouteTracker from '../common/util/PageRouteTracker';
import { gameRepository } from '../data/GameRepository';
import { GameMode } from '../game/models/GameMode';
import { SessionHistoryEntry } from '../data/models/GameRepositoryTypes';

@Component
export struct History {
  @State selectedMode: string = 'all';
  @State selectedSort: string = 'newest';
  @State entries: SessionHistoryEntry[] = [];

  onPageShow() {
    PageRouteTracker.setCurrentPage(PageRoutes.HISTORY);
    this.entries = gameRepository.getHistory().slice().reverse();
  }

  private filteredEntries(): SessionHistoryEntry[] {
    const filtered = this.selectedMode === 'all' ? this.entries : this.entries.filter((item) => item.mode === this.selectedMode);
    return filtered.slice().sort((a: SessionHistoryEntry, b: SessionHistoryEntry) => {
      if (this.selectedSort === 'oldest') {
        return a.completedAt - b.completedAt;
      }
      if (this.selectedSort === 'score') {
        return b.score - a.score || b.completedAt - a.completedAt;
      }
      return b.completedAt - a.completedAt;
    });
  }

  build() {
    Column() {
      Scroll() {
        Column() {
        Text('History')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#B31252')
        Text('Completed sessions')
          .fontSize(12)
          .fontColor('#7A3654')
          .opacity(0.75)
          .margin({ top: 2, bottom: 8 })
        Row() {
          Button('All').layoutWeight(1).height(30).fontSize(12).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(15).onClick(() => this.selectedMode = 'all')
          Button('Classic').layoutWeight(1).height(30).fontSize(12).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(15).margin({ left: 6 }).onClick(() => this.selectedMode = GameMode.CLASSIC)
        }
        .width('100%')
        Row() {
          Button('Timed').layoutWeight(1).height(30).fontSize(12).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(15).onClick(() => this.selectedMode = GameMode.TIMED)
          Button('Streak').layoutWeight(1).height(30).fontSize(12).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(15).margin({ left: 6 }).onClick(() => this.selectedMode = GameMode.STREAK)
        }
        .width('100%')
        .margin({ top: 6 })

        Row() {
          Button('Newest').layoutWeight(1).height(30).fontSize(11).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(15).onClick(() => this.selectedSort = 'newest')
          Button('Oldest').layoutWeight(1).height(30).fontSize(11).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(15).onClick(() => this.selectedSort = 'oldest')
          Button('Top score').layoutWeight(1).height(30).fontSize(11).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(15).onClick(() => this.selectedSort = 'score')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 8 })

        if (this.filteredEntries().length === 0) {
          Text(this.entries.length === 0 ? 'No sessions recorded yet.' : 'No sessions match this filter.')
            .fontSize(14)
            .fontColor('#7A3654')
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 18 })
        } else {
          ForEach(this.filteredEntries(), (entry: SessionHistoryEntry) => {
            HistoryRow({ entry: entry })
              .margin({ top: 10 })
          }, (entry: SessionHistoryEntry) => entry.sessionId)
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
