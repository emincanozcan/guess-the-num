import PageRoutes from '../common/constants/PageRoutes';

@Entry
@Component
struct Index {
  private hasRedirected: boolean = false;

  onPageShow() {
    if (this.hasRedirected) {
      return;
    }

    this.hasRedirected = true;
    void this.openHome();
  }

  private async openHome(): Promise<void> {
    try {
      await this.getUIContext().getRouter().replaceUrl({ url: PageRoutes.HOME });
    } catch (_error) {
    }
  }

  build() {
    Column() {
      Text('Loading...')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}
