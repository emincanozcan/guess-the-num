import localUnitTest from './LocalUnit.test';
import gameEngineTest from './GameEngine.test';
import gameRepositoryTest from './GameRepository.test';
import deviceServicesTest from './DeviceServices.test';
import harmonyReminderAdapterTest from './HarmonyReminderAdapter.test';

export default function testsuite() {
  localUnitTest();
  gameEngineTest();
  gameRepositoryTest();
  deviceServicesTest();
  harmonyReminderAdapterTest();
}
