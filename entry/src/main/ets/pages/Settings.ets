import PageRoutes from '../common/constants/PageRoutes';
import { dailyReminderService } from '../common/services/DailyReminderService';
import PageRouteTracker from '../common/util/PageRouteTracker';
import { gameRepository } from '../data/GameRepository';
import { ReminderScheduleStatus } from '../data/models/GameRepositoryTypes';

@Component
export struct Settings {
  @State backgroundPolicy: string = 'penalize';
  @State timedBackgroundPolicy: string = 'pause';
  @State backgroundPenaltyEnabled: boolean = true;
  @State keepSnapshots: boolean = true;
  @State hapticsEnabled: boolean = true;
  @State reminderEnabled: boolean = false;
  @State reminderHour: number = 20;
  @State reminderMinute: number = 0;
  @State reminderStatus: ReminderScheduleStatus = 'idle';
  @State reminderToken: string = '';
  @State reminderStatusMessage: string = 'No reminder scheduled.';

  onPageShow() {
    PageRouteTracker.setCurrentPage(PageRoutes.SETTINGS);
    const settings = gameRepository.getSettings();
    this.backgroundPolicy = settings.backgroundPolicy;
    this.timedBackgroundPolicy = settings.timedBackgroundPolicy;
    this.backgroundPenaltyEnabled = settings.backgroundPenaltyEnabled;
    this.keepSnapshots = settings.keepLifecycleSnapshots;
    this.hapticsEnabled = settings.hapticsEnabled;
    this.reminderEnabled = settings.dailyReminderEnabled;
    this.reminderHour = settings.dailyReminderHour;
    this.reminderMinute = settings.dailyReminderMinute;
    this.reminderStatus = settings.dailyReminderStatus;
    this.reminderToken = settings.dailyReminderToken;
    this.reminderStatusMessage = this.buildReminderStatusMessage();
  }

  private updateSettings() {
    gameRepository.updateSettings({
      backgroundPolicy: this.backgroundPolicy as 'penalize' | 'log-only',
      timedBackgroundPolicy: this.timedBackgroundPolicy as 'pause' | 'log-only',
      backgroundPenaltyEnabled: this.backgroundPenaltyEnabled,
      keepLifecycleSnapshots: this.keepSnapshots,
      hapticsEnabled: this.hapticsEnabled,
      dailyReminderEnabled: this.reminderEnabled,
      dailyReminderHour: this.reminderHour,
      dailyReminderMinute: this.reminderMinute,
      dailyReminderStatus: this.reminderStatus,
      dailyReminderToken: this.reminderToken,
      dailyReminderUpdatedAt: new Date().getTime()
    });
  }

  private policyLabel(): string {
    return this.backgroundPolicy === 'log-only' ? 'Log only' : 'Cost a life';
  }

  private timedPolicyLabel(): string {
    return this.timedBackgroundPolicy === 'log-only' ? 'Log only' : 'Pause timer';
  }

  private buildReminderStatusMessage(): string {
    switch (this.reminderStatus) {
      case 'scheduled':
        return `Scheduled for ${this.timeLabel()}.`;
      case 'cancelled':
        return 'Reminder cancelled.';
      case 'unsupported':
        return 'Reminders unavailable on this device/runtime.';
      case 'failed':
        return 'Reminder operation failed. Try again.';
      case 'idle':
      default:
        return this.reminderEnabled ? `Ready to schedule at ${this.timeLabel()}.` : 'No reminder scheduled.';
    }
  }

  private timeLabel(): string {
    return `${this.reminderHour}`.padStart(2, '0') + ':' + `${this.reminderMinute}`.padStart(2, '0');
  }

  private adjustReminderHour(delta: number): void {
    this.reminderHour = (this.reminderHour + delta + 24) % 24;
    void this.applyReminderTimeChange();
  }

  private adjustReminderMinute(delta: number): void {
    this.reminderMinute = (this.reminderMinute + delta + 60) % 60;
    void this.applyReminderTimeChange();
  }

  private async applyReminderTimeChange(): Promise<void> {
    if (this.reminderEnabled) {
      const operation = this.reminderToken
        ? await dailyReminderService.replaceDaily(this.reminderHour, this.reminderMinute, this.reminderToken)
        : await dailyReminderService.scheduleDaily(this.reminderHour, this.reminderMinute);
      if (operation.status === 'scheduled') {
        this.reminderEnabled = true;
        this.reminderToken = operation.reminderToken ?? '';
      }
      this.reminderStatus = operation.status;
      this.reminderStatusMessage = operation.message;
      this.updateSettings();
      return;
    }

    this.updateSettings();
    this.reminderStatusMessage = this.buildReminderStatusMessage();
  }

  private async scheduleReminder(): Promise<void> {
    const operation = (this.reminderEnabled && this.reminderToken)
      ? await dailyReminderService.replaceDaily(this.reminderHour, this.reminderMinute, this.reminderToken)
      : await dailyReminderService.scheduleDaily(this.reminderHour, this.reminderMinute);

    if (operation.status === 'scheduled') {
      this.reminderEnabled = true;
      this.reminderToken = operation.reminderToken ?? '';
    }
    this.reminderStatus = operation.status;
    this.reminderStatusMessage = operation.message;
    this.updateSettings();
  }

  private async cancelReminder(): Promise<void> {
    if (this.reminderEnabled && !this.reminderToken) {
      this.reminderEnabled = false;
      this.reminderStatus = 'idle';
      this.reminderStatusMessage = 'Reminder reset. Schedule again to create a tracked reminder.';
      this.updateSettings();
      return;
    }

    const operation = await dailyReminderService.cancelDaily(this.reminderToken);
    if (operation.status === 'cancelled') {
      this.reminderEnabled = false;
      this.reminderToken = '';
    }
    this.reminderStatus = operation.status;
    this.reminderStatusMessage = operation.message;
    this.updateSettings();
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Text('Settings')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#B31252')

          Text('Game behavior + reminders')
            .fontSize(12)
            .opacity(0.75)
            .margin({ top: 2, bottom: 8 })
            .fontColor('#B31252')
          Text('Background policy')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#B31252')
          Row() {
            Button('Cost a life').layoutWeight(1).height(32).fontSize(12).fontColor('#FFFFFF').backgroundColor('#E58A2B').borderRadius(16).onClick(() => { this.backgroundPolicy = 'penalize'; this.backgroundPenaltyEnabled = true; this.updateSettings(); })
            Button('Log only').layoutWeight(1).height(32).fontSize(12).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(16).margin({ left: 8 }).onClick(() => { this.backgroundPolicy = 'log-only'; this.backgroundPenaltyEnabled = false; this.updateSettings(); })
          }.width('100%').margin({ top: 8 })

          Text(`Current: ${this.policyLabel()}`)
            .fontSize(12)
            .opacity(0.7)
            .margin({ top: 4, bottom: 12 })
            .fontColor('#B31252')

          Text('Timed session background')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#B31252')
          Row() {
            Button('Pause timer').layoutWeight(1).height(32).fontSize(12).fontColor('#FFFFFF').backgroundColor('#D96C8B').borderRadius(16).onClick(() => { this.timedBackgroundPolicy = 'pause'; this.updateSettings(); })
            Button('Log only').layoutWeight(1).height(32).fontSize(12).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(16).margin({ left: 8 }).onClick(() => { this.timedBackgroundPolicy = 'log-only'; this.updateSettings(); })
          }.width('100%').margin({ top: 8 })

          Text(`Current: ${this.timedPolicyLabel()}`)
            .fontSize(12)
            .opacity(0.7)
            .margin({ top: 4, bottom: 12 })
            .fontColor('#B31252')

          Row() {
            Text('Keep lifecycle snapshots').layoutWeight(1)
              .fontColor('#B31252')
            Button(this.keepSnapshots ? 'On' : 'Off').height(30).fontSize(12).fontColor('#FFFFFF').backgroundColor(this.keepSnapshots ? '#C84D7C' : '#D8B89C').borderRadius(15).onClick(() => { this.keepSnapshots = !this.keepSnapshots; this.updateSettings(); })
          }.width('100%').margin({ bottom: 8 })

          Row() {
            Text('Haptics').layoutWeight(1)
              .fontColor('#B31252')

            Button(this.hapticsEnabled ? 'On' : 'Off').height(30).fontSize(12).fontColor('#FFFFFF').backgroundColor(this.hapticsEnabled ? '#C84D7C' : '#D8B89C').borderRadius(15).onClick(() => {
              this.hapticsEnabled = !this.hapticsEnabled;
              this.updateSettings();
            })
          }.width('100%').margin({ bottom: 12 })

          Text('Daily reminder')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#B31252')

          Row() {
            Button('-1h').layoutWeight(1).height(32).fontSize(12).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(16).onClick(() => this.adjustReminderHour(-1))
            Text(this.timeLabel()).layoutWeight(1).textAlign(TextAlign.Center).fontColor('#B31252')
            Button('+1h').layoutWeight(1).height(32).fontSize(12).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(16).onClick(() => this.adjustReminderHour(1))
          }.width('100%').margin({ top: 8 })
          Row() {
            Button('-15m').layoutWeight(1).height(32).fontSize(12).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(16).onClick(() => this.adjustReminderMinute(-15))
            Text(' ').layoutWeight(1)
            Button('+15m').layoutWeight(1).height(32).fontSize(12).fontColor('#7A3654').backgroundColor('#FFF7FB').borderRadius(16).onClick(() => this.adjustReminderMinute(15))
          }.width('100%').margin({ top: 6 })
          Row() {
            Button('Schedule').layoutWeight(1).height(34).fontSize(13).fontColor('#FFFFFF').backgroundColor('#E58A2B').borderRadius(17).onClick(() => { void this.scheduleReminder(); })
            Button('Cancel').layoutWeight(1).height(34).fontSize(13).fontColor('#FFFFFF').backgroundColor('#D96C8B').borderRadius(17).margin({ left: 8 }).onClick(() => { void this.cancelReminder(); })
          }.width('100%').margin({ top: 8, bottom: 6 })
          Text(this.reminderStatusMessage)
            .fontSize(12)
            .opacity(0.75)
            .width('100%')
            .margin({ bottom: 8 })
            .fontColor('#B31252')

          Text('Classic can cost a life. Timed can pause or just log backgrounding.')
            .fontSize(12)
            .opacity(0.75)
            .width('100%')
            .fontColor('#B31252')
        }
        .width('100%')
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
}
