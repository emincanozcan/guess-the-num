import CommonConstants from '../common/constants/CommonConstants';
import { globalMessageStore as GlobalDataStore } from '../common/util/GlobalDataStorage';

@Entry
@Component
struct Index {
  // Game state stored in GlobalMessageStore
  @StorageLink('userLives') lives: number = GlobalDataStore.userLives;
  @StorageLink('gameOver') isGameOver: boolean = GlobalDataStore.isGameOver;
  // UI state variables
  @State displayMessage: string = ''; // Message shown on the screen (lives, wrong answer, etc.)
  @State secretNumber: number = 1; // Secret number to be guessed
  @State options: number[] = [1, 3]; // Two options shown to the player
  @State correctCount: number = 0;
  @State wrongCount: number = 0;
  // Predefined numbers and counters
  private predefinedNumbers: number[] = [
    1, 2, 3, 4, 5, 1, 2, 3, 4, 5,
    1, 2, 3, 4, 5, 1, 2, 3, 4, 5,
    1, 2, 3, 4, 5, 1, 2, 3, 4, 5
  ];
  private currentIndex: number = 0;
  private turn: number = 0;

  aboutToAppear() {
    this.generateNewRound();
    this.updateDisplayMessage();
  }

  onPageShow() {
    this.updateDisplayMessage();
  }

  generateNewRound() {
    const option1 = this.predefinedNumbers[this.currentIndex % this.predefinedNumbers.length];
    const option2 = this.predefinedNumbers[(this.currentIndex + 1) % this.predefinedNumbers.length];

    this.options = [option1, option2];

    this.secretNumber = this.options[this.turn % 2];

    this.currentIndex++;
    this.turn++;

    this.displayMessage = '❤️'.repeat(this.lives);
  }

  updateDisplayMessage() {
    if (this.isGameOver) {
      this.displayMessage = 'You ran out of lives! Game over.';
    } else if (this.displayMessage !== 'Wrong answer!' && !this.displayMessage.startsWith('Wrong answer')) {
      this.displayMessage = '❤️'.repeat(this.lives);
    }
  }

  handleGuess(guess: number) {
    if (guess !== this.secretNumber) {
      GlobalDataStore.userLives--;
      this.lives = GlobalDataStore.userLives;

      if (this.lives <= 0) {
        GlobalDataStore.isGameOver = true;
        this.isGameOver = true;
        this.displayMessage = 'Game over!';
      } else {
        this.displayMessage = `Wrong! It was ${this.secretNumber}`;
      }
    } else {
      this.displayMessage = 'Correct!';
    }

    setTimeout(() => {
      if (!this.isGameOver) {
        this.generateNewRound();
      }
    }, 1000);
  }

  build() {
    Column() {
      Text(this.displayMessage)
        .fontSize($r('app.float.page_text_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor(
          this.isGameOver ? Color.Red : this.displayMessage.startsWith('Correct') ? Color.Green :
            this.displayMessage.startsWith('Wrong') ? Color.Orange : Color.Blue
        )
        .padding($r('app.float.text_padding'))
        .margin({ top: $r('app.float.small_margin') })
        .alignSelf(ItemAlign.Center)

      if (!this.isGameOver) {
        QuestionMark()

        Row() {
          Button(`${this.options[0]}`)
            .margin($r('app.float.button_padding'))
            .margin($r('app.float.small_margin'))
            .backgroundColor(Color.Orange)
            .fontColor(Color.White)
            .borderRadius($r('app.float.button_border_radius'))
            .fontSize($r('app.float.button_font_size'))
            .onClick(() => this.handleGuess(this.options[0]))

          Button(`${this.options[1]}`)
            .margin($r('app.float.button_padding'))
            .margin($r('app.float.small_margin'))
            .backgroundColor(Color.Orange)
            .fontColor(Color.White)
            .borderRadius($r('app.float.button_border_radius'))
            .fontSize($r('app.float.button_font_size'))
            .onClick(() => this.handleGuess(this.options[1]))
        }
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)
      } else {
        Button('Play Again')
          .margin($r('app.float.small_padding'))
          .margin($r('app.float.play_again_margin'))
          .backgroundColor(Color.Green)
          .fontColor(Color.White)
          .borderRadius($r('app.float.play_again_border_radius'))
          .fontSize($r('app.float.play_again_font_size'))
          .onClick(() => {
            this.correctCount = 0;
            this.wrongCount = 0;
            GlobalDataStore.userLives = 3;
            this.lives = GlobalDataStore.userLives;
            GlobalDataStore.isGameOver = false;
            this.isGameOver = false;
            this.currentIndex = 0;
            this.turn = 0;
            this.generateNewRound();
            this.updateDisplayMessage();
          })
      }
    }
    .width(CommonConstants.FULL_WIDTH)
    .height(CommonConstants.FULL_HEIGHT)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.White)
    .linearGradient({
      direction: GradientDirection.Left,
      repeating: true,
      colors: [
        [$r('app.color.gradient_start'), 0.0],
        [$r('app.color.gradient_middle'), 0.5],
        [$r('app.color.gradient_end'), 1.0]
      ]
    })
  }
}

@Component
struct QuestionMark {
  @State rotateAngle: number = 0;
  private rotateTimer: number | null = null;

  aboutToAppear() {
    this.startRotateAnimation();
  }

  aboutToDisappear() {
    this.stopRotateAnimation();
  }

  startRotateAnimation() {
    this.stopRotateAnimation();
    this.rotateTimer = setInterval(() => {
      this.rotateAngle += CommonConstants.ROTATE_STEP;
    }, CommonConstants.ROTATE_INTERVAL_MS);
  }

  stopRotateAnimation() {
    if (this.rotateTimer) {
      clearInterval(this.rotateTimer);
      this.rotateTimer = null;
    }
  }

  build() {
    Text('❓')
      .fontSize($r('app.float.question_mark_font_size'))
      .padding($r('app.float.text_padding'))
      .alignSelf(ItemAlign.Center)
      .fontColor(Color.Blue)
      .rotate({ angle: this.rotateAngle })
      .animation({
        curve: Curve.Linear,
        playMode: PlayMode.Normal,
      })
  }
}
