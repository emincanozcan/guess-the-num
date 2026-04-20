import PageRoutes from '../constants/PageRoutes';

export default class AppNavigator {
  private static readonly PATH_STACK_KEY: string = 'appNavPathStack';
  private static readonly PARAMS_KEY_PREFIX: string = 'appNavParams:';

  static setPathStack(pathStack: NavPathStack): void {
    AppStorage.setOrCreate<NavPathStack>(AppNavigator.PATH_STACK_KEY, pathStack);
  }

  static push(routeName: string, params?: Object): void {
    const pathStack = AppNavigator.getPathStack();
    if (!pathStack) {
      return;
    }
    if (params) {
      AppNavigator.setParams(routeName, params);
    }
    pathStack.pushPath({ name: routeName, param: params ?? null });
  }

  static replace(routeName: string, params?: Object): void {
    const pathStack = AppNavigator.getPathStack();
    if (!pathStack) {
      return;
    }
    if (params) {
      AppNavigator.setParams(routeName, params);
    }
    pathStack.replacePath({ name: routeName, param: params ?? null });
  }

  static clearToHome(): void {
    const pathStack = AppNavigator.getPathStack();
    if (!pathStack) {
      return;
    }
    pathStack.clear();
    pathStack.pushPath({ name: PageRoutes.HOME });
  }

  static setParams(routeName: string, params: Object): void {
    AppStorage.setOrCreate<Object>(`${AppNavigator.PARAMS_KEY_PREFIX}${routeName}`, params);
  }

  static consumeParams<T extends Object>(routeName: string): T | undefined {
    const key = `${AppNavigator.PARAMS_KEY_PREFIX}${routeName}`;
    const params = AppStorage.get<T>(key);
    AppStorage.delete(key);
    return params;
  }

  private static getPathStack(): NavPathStack | undefined {
    return AppStorage.get<NavPathStack>(AppNavigator.PATH_STACK_KEY);
  }
}
