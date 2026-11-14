"""Regression checks for the local ARTEMIS Android driver remediation."""
import ast
import asyncio
import logging
import os
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch

# Compile the actual methods without starting the SDK's model/provider imports.
source = Path(__file__).resolve().parents[2] / 'tools/artemis/artemis/drivers/android/adb_driver.py'
tree = ast.parse(source.read_text(encoding='utf8'))
driver_node = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == 'AndroidAdbDriver')
driver_node.bases = []
driver_node.body = [node for node in driver_node.body if isinstance(node, ast.AsyncFunctionDef)
                    and node.name in ('input_text', '_verified_ascii_input', 'launch_app', 'stop_app', 'press_key', 'get_screen_data')]
escape = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == '_escape_for_adb_text')
namespace = {'asyncio': asyncio, 'os': os, 'logger': logging.getLogger('test-driver'), 'KeyCode': object, 'ScreenData': object}
exec(compile(ast.Module(body=[escape, driver_node], type_ignores=[]), str(source), 'exec'), namespace)
AndroidAdbDriver = namespace['AndroidAdbDriver']
actuator_source = source.parents[2] / 'mcp/actuators/adb.py'
actuator_tree = ast.parse(actuator_source.read_text(encoding='utf8'))
actuator_node = next(node for node in actuator_tree.body if isinstance(node, ast.ClassDef) and node.name == 'AdbActuator')
actuator_node.bases = []
actuator_node.body = [node for node in actuator_node.body if isinstance(node, ast.AsyncFunctionDef) and node.name == 'input_text']
action_result = SimpleNamespace(success=lambda *args, **kwargs: SimpleNamespace(ok=True),
                                failure=lambda *args, **kwargs: SimpleNamespace(ok=False))
actuator_namespace = {'os': os, 'ActionResult': action_result}
exec(compile(ast.Module(body=[actuator_node], type_ignores=[]), str(actuator_source), 'exec'), actuator_namespace)
AdbActuator = actuator_namespace['AdbActuator']

PKG = 'com.longevityplate.longevity_plate'

def screen(text, package=PKG, focused='true'):
    return SimpleNamespace(ui_elements=[{'package': package, 'class': 'android.widget.EditText',
                                        'focused': focused, 'text': text}])

class VerifiedInputTest(unittest.IsolatedAsyncioTestCase):
    def driver(self, screens, package=PKG):
        driver = object.__new__(AndroidAdbDriver)
        driver.device = SimpleNamespace(shell=Mock(return_value=''))
        driver.field = Mock()
        driver._ui_adb_client = SimpleNamespace(_device=Mock(return_value=driver.field))
        driver.get_current_package = AsyncMock(return_value=package)
        driver.get_screen_data = AsyncMock(side_effect=screens)
        return driver

    async def test_native_input_replaces_entire_old_value_and_reads_back(self):
        old = 'ARTEMIS_NO_SUCH_ARTICLE_R2_remediation_20261114'
        driver = self.driver([screen(old), screen('dia an')])
        self.assertTrue(await driver._verified_ascii_input('dia an', True, PKG))
        driver.field.set_text.assert_called_once_with('dia an')
        driver.device.shell.assert_not_called()

    async def test_clipboard_without_app_value_is_failure(self):
        driver = self.driver([screen(''), screen('')])
        self.assertFalse(await driver._verified_ascii_input('ARTEMIS_TEST', True, PKG))

    async def test_other_package_or_missing_focus_prevents_all_input(self):
        for package, nodes in [('other.app', []), (PKG, [screen('', focused='false')]),
                               (PKG, [screen('', package='keyboard.app')])]:
            driver = self.driver(nodes, package)
            self.assertFalse(await driver._verified_ascii_input('test', True, PKG))
            driver.device.shell.assert_not_called()
            driver.field.set_text.assert_not_called()

    async def test_append_checks_combined_value(self):
        driver = self.driver([screen('abc'), screen('abcdef')])
        self.assertTrue(await driver._verified_ascii_input('def', False, PKG))

    async def test_opt_in_dispatches_ascii_to_verified_path(self):
        driver = self.driver([])
        driver._verified_ascii_input = AsyncMock(return_value=False)
        with patch.dict('os.environ', {'ARTEMIS_INPUT_VERIFY_PACKAGE': PKG}):
            self.assertFalse(await driver.input_text('fixture'))
        driver._verified_ascii_input.assert_awaited_once_with('fixture', True, PKG)

    async def test_scope_blocks_launch_stop_and_home_before_device_action(self):
        driver = self.driver([])
        with patch.dict('os.environ', {'ARTEMIS_SCOPE_PACKAGE': PKG}):
            self.assertFalse(await driver.launch_app('unrelated.app'))
            self.assertFalse(await driver.stop_app('unrelated.app'))
            self.assertFalse(await driver.press_key('HOME'))
            self.assertFalse(await driver.press_key('KEYCODE_HOME'))
            self.assertFalse(await driver.press_key(187))
        driver.device.shell.assert_not_called()

    async def test_scope_prevents_capture_of_unrelated_app(self):
        driver = self.driver([], 'unrelated.app')
        with patch.dict('os.environ', {'ARTEMIS_SCOPE_PACKAGE': PKG}):
            with self.assertRaisesRegex(RuntimeError, 'outside test scope'):
                await AndroidAdbDriver.get_screen_data(driver)
        driver.device.shell.assert_not_called()

    async def test_actuator_delegates_replacement_to_verified_driver(self):
        actuator = object.__new__(AdbActuator)
        actuator.controller = SimpleNamespace(type_text=AsyncMock(return_value=True), erase_text=AsyncMock())
        with patch.dict('os.environ', {'ARTEMIS_INPUT_VERIFY_PACKAGE': PKG}):
            result = await actuator.input_text('ARTEMIS_TEST', clear_exist=True)
        self.assertTrue(result.ok)
        actuator.controller.type_text.assert_awaited_once_with('ARTEMIS_TEST', clear_existing=True)
        actuator.controller.erase_text.assert_not_awaited()

    async def test_actuator_keeps_legacy_append_when_opt_in_disabled(self):
        actuator = object.__new__(AdbActuator)
        actuator.controller = SimpleNamespace(type_text=AsyncMock(return_value=True), press_key=AsyncMock())
        with patch.dict('os.environ', {'ARTEMIS_INPUT_VERIFY_PACKAGE': ''}):
            result = await actuator.input_text('hello', clear_exist=False)
        self.assertTrue(result.ok)
        actuator.controller.press_key.assert_awaited_once_with('123')
        actuator.controller.type_text.assert_awaited_once_with('hello', clear_existing=False)

if __name__ == '__main__':
    unittest.main()
