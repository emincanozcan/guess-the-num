import { GameMode } from '../../game/models/GameMode';
import { SessionHistoryEntry } from '../../data/models/GameRepositoryTypes';

@Component
export struct HistoryRow {
  entry: SessionHistoryEntry = {
    sessionId: '',
    mode: GameMode.CLASSIC,
    reason: '',
    summary: '',
    score: 0,
    livesRemaining: 0,
    correctCount: 0,
    wrongCount: 0,
    bestStreak: 0,
    completedRounds: 0,
    completedAt: 0
  };

  build() {
    Column() {
      Row() {
        Text(this.entry.mode.toUpperCase())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#8B3A62')
        Text(`${this.entry.score} pts`)
          .fontSize(12)
          .fontColor('#B31252')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text(this.entry.summary || this.entry.reason)
        .fontSize(13)
        .fontColor('#7A3654')
        .margin({ top: 4 })

      Text(`${this.entry.correctCount} right • ${this.entry.wrongCount} wrong • ${this.formatTime(this.entry.completedAt)}`)
        .fontSize(11)
        .fontColor('#8B3A62')
        .opacity(0.7)
        .margin({ top: 2 })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor('#FFF7FB')
  }

  private formatTime(timestamp: number): string {
    if (timestamp <= 0) {
      return 'Unknown time';
    }
    return new Date(timestamp).toLocaleDateString();
  }
}
