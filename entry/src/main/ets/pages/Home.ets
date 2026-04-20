import PageRoutes from '../common/constants/PageRoutes';
import AppNavigator from '../common/util/AppNavigator';
import PageRouteTracker from '../common/util/PageRouteTracker';
import { gameRepository } from '../data/GameRepository';
import { GameMode } from '../game/models/GameMode';

class GameNavigationParams {
  mode: string = GameMode.CLASSIC;
  resumeClassic: string = 'false';
}

@Component
export struct Home {
  @State welcomeText: string = 'Ready for a quick round?';
  @State profileText: string = 'New player';
  @State sessionText: string = 'No session yet';
  @State quickResumeText: string = 'Resume classic session';
  @State quickResumeEnabled: boolean = false;

  onPageShow() {
    PageRouteTracker.setCurrentPage(PageRoutes.HOME);
    this.refreshDashboard();
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Blank()
            .height(10)

          Text('Guess the Num')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#B31252')
            .width('100%')
            .textAlign(TextAlign.Center)
          Text(this.welcomeText)
            .fontSize(12)
            .fontColor('#7A3654')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 2, bottom: 8 })
          Text(this.profileText)
            .fontSize(12)
            .fontColor('#7A3654')
            .textAlign(TextAlign.Center)
            .width('100%')

          Text(this.sessionText)
            .fontSize(12)
            .fontColor('#9A4A67')
            .margin({ top: 2, bottom: 8 })
            .textAlign(TextAlign.Center)
            .width('100%')

          Button(this.quickResumeText)
            .width('100%')
            .height(36)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor(this.quickResumeEnabled ? '#E58A2B' : '#D8B89C')
            .borderRadius(18)
            .enabled(this.quickResumeEnabled)
            .onClick(() => {
              this.startMode(GameMode.CLASSIC, true);
            })

          Text('Challenges')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#B31252')
            .margin({ top: 16, bottom: 8 })
            .width('100%')

          Button('Classic')
            .width('100%')
            .height(34)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#E58A2B')
            .borderRadius(17)
            .margin({ bottom: 8 })
            .onClick(() => {
              this.startMode(GameMode.CLASSIC);
            })

          Button('Timed')
            .width('100%')
            .height(34)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#D96C8B')
            .borderRadius(17)
            .margin({ bottom: 8 })
            .onClick(() => {
              this.startMode(GameMode.TIMED);
            })

          Button('Streak')
            .width('100%')
            .height(34)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#C84D7C')
            .borderRadius(17)
            .onClick(() => {
              this.startMode(GameMode.STREAK);
            })

          Column() {
            Button('Stats')
              .width('100%')
              .height(32)
              .fontSize(12)
              .fontColor('#7A3654')
              .backgroundColor('#FFF7FB')
              .borderRadius(16)
              .margin({ top: 10 })
              .onClick(() => {
                this.open(PageRoutes.STATS);
              })

            Button('History')
              .width('100%')
              .height(32)
              .fontSize(12)
              .fontColor('#7A3654')
              .backgroundColor('#FFF7FB')
              .borderRadius(16)
              .margin({ top: 8 })
              .onClick(() => {
                this.open(PageRoutes.HISTORY);
              })
          }

          Button('Settings')
            .width('100%')
            .height(32)
            .fontSize(12)
            .fontColor('#7A3654')
            .backgroundColor('#FFF7FB')
            .borderRadius(16)
            .margin({ top: 8 })
            .onClick(() => {
              this.open(PageRoutes.SETTINGS);
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding(12)
        .padding({ bottom: 20 })
      }
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#FFE6F2')
  }

  private refreshDashboard() {
    const stats = gameRepository.getStats();
    const lastSession = gameRepository.getLastSession();

    this.welcomeText = 'Ready for a round?';
    this.profileText = `❤️ ${gameRepository.getClassicLives()}  Best ${stats.bestScore}  Streak ${stats.bestStreak}`;
    this.sessionText = lastSession.updatedAt > 0
      ? `${lastSession.mode.toUpperCase()} • Score ${lastSession.score}`
      : 'No session yet';
    this.quickResumeEnabled = gameRepository.hasActiveClassicSession() && !lastSession.gameOver;
    this.quickResumeText = this.quickResumeEnabled ? 'Resume classic session' : 'Resume classic session';
  }

  private open(route: string): void {
    AppNavigator.push(route);
  }

  private startMode(mode: GameMode, resumeClassic: boolean = false): void {
    const params: GameNavigationParams = new GameNavigationParams();
    params.mode = mode;
    if (resumeClassic) {
      params.resumeClassic = 'true';
      AppNavigator.push(PageRoutes.GAME, params);
      return;
    }
    AppNavigator.push(PageRoutes.GAME, params);
  }
}
