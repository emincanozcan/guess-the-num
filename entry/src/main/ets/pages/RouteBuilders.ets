import { Game } from './Game';
import { History } from './History';
import { Home } from './Home';
import { Logs } from './Logs';
import { Result } from './Result';
import { Settings } from './Settings';
import { Stats } from './Stats';

@Builder
export function HomeRouteBuilder() {
  NavDestination() {
    Home();
  }
  .hideTitleBar(true)
}

@Builder
export function GameRouteBuilder() {
  NavDestination() {
    Game();
  }
  .hideTitleBar(true)
}

@Builder
export function ResultRouteBuilder() {
  NavDestination() {
    Result();
  }
  .hideTitleBar(true)
}

@Builder
export function StatsRouteBuilder() {
  NavDestination() {
    Stats();
  }
  .hideTitleBar(true)
}

@Builder
export function HistoryRouteBuilder() {
  NavDestination() {
    History();
  }
  .hideTitleBar(true)
}

@Builder
export function LogsRouteBuilder() {
  NavDestination() {
    Logs();
  }
  .hideTitleBar(true)
}

@Builder
export function SettingsRouteBuilder() {
  NavDestination() {
    Settings();
  }
  .hideTitleBar(true)
}
