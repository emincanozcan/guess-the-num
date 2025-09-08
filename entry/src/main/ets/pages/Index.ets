import CommonConstants from '../common/constants/CommonConstants';
import { GlobalMessageStore as GlobalDataStore } from '../common/util/GlobalDataStorage';

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

  aboutToAppear() {
    // Initialize the round and message when the page appears
    this.generateNewRound();
    this.updateDisplayMessage();
  }

  onPageShow() {
    // Refresh display message when the page comes to the foreground
    this.updateDisplayMessage();
  }

  generateNewRound() {
    // Generate two random unique numbers from the list [1..5]
    const allOptions = [1, 2, 3, 4, 5];

    let firstIndex = Math.floor(Math.random() * allOptions.length);
    let secondIndex = firstIndex;

    while (secondIndex === firstIndex) {
      secondIndex = Math.floor(Math.random() * allOptions.length);
    }

    this.options = [allOptions[firstIndex], allOptions[secondIndex]];
    // Randomly pick one of them as the secret number
    this.secretNumber = this.options[Math.floor(Math.random() * this.options.length)];
    // Show hearts equal to remaining lives
    this.displayMessage = '❤️'.repeat(this.lives);
  }

  updateDisplayMessage() {
    // Update display message based on game state
    if (this.isGameOver) {
      this.displayMessage = 'You ran out of lives! Game over.';
    } else if (this.displayMessage !== 'Wrong answer!' && !this.displayMessage.startsWith('Wrong answer')) {
      this.displayMessage = '❤️'.repeat(this.lives);
    }
  }

  handleGuess(guess: number) {
    // Check the player's guess
    if (guess !== this.secretNumber) {
      // Wrong guess: reduce life
      GlobalDataStore.userLives--;
      this.lives = GlobalDataStore.userLives;

      if (this.lives <= 0) {
        // Game over if no lives left
        GlobalDataStore.isGameOver = true;
        this.isGameOver = true;
        this.displayMessage = 'Game over!';
      } else {
        // Show the correct answer when guessed wrong
        this.displayMessage = `Wrong! It was ${this.secretNumber}`;
      }
    } else {
      // Correct guess
      this.displayMessage = 'Correct!';
    }

    // Start a new round after 1 second, if game is not over
    setTimeout(() => {
      if (!this.isGameOver) {
        this.generateNewRound();
      }
    }, 1000);
  }

  build() {
    Column() {
      // Display message (lives, correct/wrong message, or game over)
      Text(this.displayMessage)
        .fontSize($r('app.float.page_text_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor(
          this.isGameOver
            ? Color.Red
            : this.displayMessage.startsWith('Correct')
            ? Color.Green
            : this.displayMessage.startsWith('Wrong')
              ? Color.Orange
              : Color.Blue
        )
        .padding($r('app.float.text_padding'))
        .margin({ top: $r('app.float.small_margin') })
        .alignSelf(ItemAlign.Center)

      if (!this.isGameOver) {
        // Rotating question mark (independent component)
        QuestionMark()

        // Two option buttons for guessing
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
        // Button to reset the game state and start a new round when the game is over
        Button("Play Again")
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
            this.generateNewRound();
            this.updateDisplayMessage();
          })
          .backgroundColor(Color.Green)
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
  // State for rotation angle
  @State rotateAngle: number = 0;
  private rotateTimer: number | null = null;

  aboutToAppear() {
    // Start rotating when component appears
    this.startRotateAnimation();
  }

  aboutToDisappear() {
    // Stop rotating when component disappears
    this.stopRotateAnimation();
  }

  startRotateAnimation() {
    // Clear any existing timer and start a new one
    this.stopRotateAnimation();
    // Rotate clockwise: add 30 degrees every 100 ms (fast spin)
    this.rotateTimer = setInterval(() => {
      this.rotateAngle += CommonConstants.ROTATE_STEP;
    }, CommonConstants.ROTATE_INTERVAL_MS);
  }

  stopRotateAnimation() {
    // Stop the timer if it's running
    if (this.rotateTimer) {
      clearInterval(this.rotateTimer);
      this.rotateTimer = null;
    }
  }

  build() {
    // Render the rotating ❓
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