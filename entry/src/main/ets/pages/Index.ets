import PageRoutes from '../common/constants/PageRoutes';
import AppNavigator from '../common/util/AppNavigator';
import { Game } from './Game';
import { History } from './History';
import { Home } from './Home';
import { Logs } from './Logs';
import { Result } from './Result';
import { Settings } from './Settings';
import { Stats } from './Stats';

@Entry
@Component
struct Index {
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear() {
    AppNavigator.setPathStack(this.pathStack);
  }

  @Builder
  private pageMap(name: string) {
    if (name === PageRoutes.GAME) {
      Game();
    } else if (name === PageRoutes.RESULT) {
      Result();
    } else if (name === PageRoutes.STATS) {
      Stats();
    } else if (name === PageRoutes.HISTORY) {
      History();
    } else if (name === PageRoutes.LOGS) {
      Logs();
    } else if (name === PageRoutes.SETTINGS) {
      Settings();
    }
  }

  build() {
    Navigation(this.pathStack) {
      Home();
    }
    .mode(NavigationMode.Stack)
    .hideNavBar(true)
    .navDestination(this.pageMap)
    .width('100%')
    .height('100%')
  }
}
