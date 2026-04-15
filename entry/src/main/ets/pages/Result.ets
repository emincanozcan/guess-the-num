import PageRoutes from '../common/constants/PageRoutes';
import AppNavigator from '../common/util/AppNavigator';
import PageRouteTracker from '../common/util/PageRouteTracker';
import { gameRepository } from '../data/GameRepository';
import { GameMode } from '../game/models/GameMode';
import { GameResultReason } from '../game/models/GameResult';

class ResultRouteParams {
  sessionId: string = '';
  mode: string = GameMode.CLASSIC;
  reason: string = '';
  summary: string = '';
}

class GameRouteParams {
  mode: string = GameMode.CLASSIC;
  resumeClassic: string = 'false';
}

@Component
export struct Result {
  @State modeLabel: string = 'Game';
  @State summaryText: string = 'No completed session found.';
  @State scoreText: string = 'Score 0';
  @State detailText: string = '';
  @State replayMode: GameMode = GameMode.CLASSIC;

  onPageShow() {
    PageRouteTracker.setCurrentPage(PageRoutes.RESULT);
    this.refreshResult();
  }

  private refreshResult() {
    const params = AppNavigator.consumeParams<ResultRouteParams>(PageRoutes.RESULT);
    const completed = gameRepository.getLastCompletedSession();
    const mode = (params?.mode as GameMode) ?? completed.mode ?? GameMode.CLASSIC;
    this.replayMode = mode;
    this.modeLabel = `${mode.charAt(0).toUpperCase() + mode.slice(1)}`;
    this.summaryText = params?.summary || completed.summary || 'Session complete.';
    this.scoreText = `Score ${completed.score}`;
    this.detailText = `${completed.correctCount}✓ • ${completed.wrongCount}✗ • Streak ${completed.bestStreak} • Rounds ${completed.completedRounds}`;
    if (completed.reason === GameResultReason.TIME_EXPIRED) {
      this.detailText += ' • Time up';
    } else if (completed.reason === GameResultReason.TARGET_STREAK_REACHED) {
      this.detailText += ' • Target streak reached';
    }
  }

  private replay(): void {
    PageRouteTracker.setCurrentPage(PageRoutes.GAME);
    const params: GameRouteParams = new GameRouteParams();
    params.mode = this.replayMode;
    AppNavigator.push(PageRoutes.GAME, params);
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Blank()
            .height(12)

          Text(`${this.modeLabel} Complete`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#B31252')
            .width('100%')
            .textAlign(TextAlign.Center)
          Text(this.summaryText)
            .fontSize(12)
            .fontColor('#7A3654')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 2, bottom: 10 })

          Column() {
            Text(this.scoreText)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#C84D7C')
              .textAlign(TextAlign.Center)
              .width('100%')

            Text(this.detailText)
              .fontSize(12)
              .fontColor('#8B3A62')
              .margin({ top: 6 })
              .textAlign(TextAlign.Center)
              .width('100%')
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 14, bottom: 14 })
          .margin({ bottom: 12 })
          .backgroundColor('#FFF7FB')
          .borderRadius(18)

          Button('Replay Mode')
            .width('100%')
            .height(36)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#E58A2B')
            .borderRadius(18)
            .margin({ bottom: 8 })
            .onClick(() => { this.replay(); })

          Button('Home')
            .width('100%')
            .height(34)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#D96C8B')
            .borderRadius(17)
            .onClick(() => {
              PageRouteTracker.setCurrentPage(PageRoutes.HOME);
              AppNavigator.clearToHome();
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 12, right: 12, bottom: 18 })
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
