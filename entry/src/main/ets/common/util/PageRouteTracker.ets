import PageRoutes from '../constants/PageRoutes';

export default class PageRouteTracker {
  private static readonly CURRENT_PAGE_KEY: string = 'currentPageRoute';
  private static readonly CURRENT_GAME_MODE_KEY: string = 'currentGameMode';

  static setCurrentPage(route: string): void {
    AppStorage.set<string>(PageRouteTracker.CURRENT_PAGE_KEY, route);
  }

  static getCurrentPage(): string {
    return AppStorage.get<string>(PageRouteTracker.CURRENT_PAGE_KEY) ?? PageRoutes.HOME;
  }

  static isCurrentPage(route: string): boolean {
    return PageRouteTracker.getCurrentPage() === route;
  }

  static setCurrentGameMode(mode: string): void {
    AppStorage.set<string>(PageRouteTracker.CURRENT_GAME_MODE_KEY, mode);
  }

  static getCurrentGameMode(): string {
    return AppStorage.get<string>(PageRouteTracker.CURRENT_GAME_MODE_KEY) ?? 'classic';
  }
}
