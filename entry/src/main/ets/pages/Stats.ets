import { StatCard } from '../common/components/StatCard';
import { AchievementBadge } from '../common/components/AchievementBadge';
import PageRoutes from '../common/constants/PageRoutes';
import PageRouteTracker from '../common/util/PageRouteTracker';
import { gameRepository } from '../data/GameRepository';
import { AchievementProgress } from '../data/models/GameRepositoryTypes';

@Component
export struct Stats {
  @State achievements: AchievementProgress[] = [];

  onPageShow() {
    PageRouteTracker.setCurrentPage(PageRoutes.STATS);
    this.achievements = gameRepository.getAchievements();
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Text('Stats')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#B31252')
          Text('Progress + badges')
            .fontSize(12)
            .fontColor('#7A3654')
            .opacity(0.75)
            .margin({ top: 2, bottom: 8 })
          Row() {
            StatCard({
              label: 'Games played',
              value: `${gameRepository.getStats().totalSessions}`,
              hint: `${gameRepository.getStats().completedSessions} completed`
            }).layoutWeight(1)
            StatCard({
              label: 'Accuracy',
              value: `${this.getAccuracy()}%`,
              hint: `${gameRepository.getStats().totalCorrect}/${gameRepository.getStats().totalCorrect +
              gameRepository.getStats().totalWrong}`
            }).layoutWeight(1).margin({ left: 8 })
          }

          Row() {
            StatCard({
              label: 'Longest streak',
              value: `${gameRepository.getStats().longestStreak || gameRepository.getStats().bestStreak}`,
              hint: 'Best streak overall'
            }).layoutWeight(1)
            StatCard({
              label: 'Best timed score',
              value: `${gameRepository.getStats().bestTimedScore}`,
              hint: `Best score ${gameRepository.getStats().bestScore}`
            }).layoutWeight(1).margin({ left: 8 })
          }

          StatCard({
            label: 'Background losses',
            value: `${gameRepository.getStats().backgroundLosses}`,
            hint: `${gameRepository.getStats().backgroundPenalties} penalties total`
          }).margin({ top: 8 })

          Text('Achievements')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#B31252')
            .margin({ top: 16, bottom: 8 })

          if (this.achievements.length === 0) {
            Text('No achievements tracked yet.')
              .fontSize(13)
              .fontColor('#7A3654')
              .opacity(0.7)
          } else {
            ForEach(this.achievements, (item: AchievementProgress) => {
              AchievementBadge({
                title: item.title,
                description: item.unlocked ? 'Unlocked' : `${item.progress}/${item.target} • ${item.description}`,
                unlocked: item.unlocked
              })
                .margin({ bottom: 8 })
            }, (item: AchievementProgress) => item.id)
            Text(`${this.getUnlockedCount()}/${this.achievements.length} unlocked`)
              .fontSize(12)
              .fontColor('#7A3654')
              .opacity(0.7)
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

  private getAccuracy(): number {
    const stats = gameRepository.getStats();
    if (stats.totalCorrect + stats.totalWrong <= 0) {
      return 0;
    }
    return Math.round((stats.totalCorrect * 100) / (stats.totalCorrect + stats.totalWrong));
  }

  private getUnlockedCount(): number {
    let count = 0;
    for (const item of this.achievements) {
      if (item.unlocked) {
        count += 1;
      }
    }
    return count;
  }
}
