import PageRoutes from '../common/constants/PageRoutes';
import AppNavigator from '../common/util/AppNavigator';
import {
  GameRouteBuilder,
  HistoryRouteBuilder,
  HomeRouteBuilder,
  LogsRouteBuilder,
  ResultRouteBuilder,
  SettingsRouteBuilder,
  StatsRouteBuilder
} from './RouteBuilders';

@Entry
@Component
struct Index {
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear() {
    AppNavigator.setPathStack(this.pathStack);
  }

  @Builder
  private pageMap(name: string) {
    if (name === PageRoutes.HOME) {
      HomeRouteBuilder();
    } else if (name === PageRoutes.GAME) {
      GameRouteBuilder();
    } else if (name === PageRoutes.RESULT) {
      ResultRouteBuilder();
    } else if (name === PageRoutes.STATS) {
      StatsRouteBuilder();
    } else if (name === PageRoutes.HISTORY) {
      HistoryRouteBuilder();
    } else if (name === PageRoutes.LOGS) {
      LogsRouteBuilder();
    } else if (name === PageRoutes.SETTINGS) {
      SettingsRouteBuilder();
    }
  }

  private seedInitialRoute(): void {
    if (this.pathStack.size() === 0) {
      this.pathStack.pushPath({ name: PageRoutes.HOME });
    }
  }

  build() {
    Navigation(this.pathStack) {}
    .mode(NavigationMode.Stack)
    .hideNavBar(true)
    .navDestination(this.pageMap)
    .onAppear(() => this.seedInitialRoute())
    .width('100%')
    .height('100%')
  }
}
