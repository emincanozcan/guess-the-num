import { describe, expect, it } from '@ohos/hypium';
import { GameMode } from '../main/ets/game/models/GameMode';
import { GameEngine } from '../main/ets/game/services/GameEngine';

export default function gameEngineTest() {
  describe('gameEngineTest', () => {
    it('creates a classic session with two choices', 0, () => {
      const engine = new GameEngine();
      const bundle = engine.createSession(GameMode.CLASSIC);

      expect(bundle.session.mode).assertEqual(GameMode.CLASSIC);
      expect(bundle.round.options.length).assertEqual(2);
      expect(bundle.round.options[0]).assertEqual(1);
      expect(bundle.round.options[1]).assertEqual(2);
      expect(bundle.round.secretNumber).assertEqual(1);
    });

    it('updates lives and streak on wrong and correct guesses', 0, () => {
      const engine = new GameEngine();
      const bundle = engine.createSession(GameMode.CLASSIC);

      const wrongResult = engine.submitGuess(bundle.session, bundle.round, 2);
      expect(bundle.session.lives).assertEqual(2);
      expect(bundle.session.wrongCount).assertEqual(1);
      expect(wrongResult.nextRound !== undefined).assertEqual(true);

      if (wrongResult.nextRound) {
        const correctResult =
          engine.submitGuess(bundle.session, wrongResult.nextRound, wrongResult.nextRound.secretNumber);
        expect(bundle.session.streak).assertEqual(1);
        expect(bundle.session.correctCount).assertEqual(1);
        expect(correctResult.isCorrect).assertEqual(true);
      }
    });
  });
}
