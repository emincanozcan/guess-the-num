import abilityTest from './Ability.test';

export default function testsuite() {
  // Centralize wearable-side tests here so the suite can grow beyond the
  // original sample wrapper as more device scenarios are added.
  abilityTest();
}
