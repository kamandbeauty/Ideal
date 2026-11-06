"""Ensure fallback filtering never hides real Godot/Android errors."""

import unittest

from check_android_log import unexpected_errors


class AndroidLogTests(unittest.TestCase):
    def setUp(self) -> None:
        self.missing = (
            'E/godot   ( 123): ERROR: vkEnumeratePhysicalDevices reported zero accessible devices.'
        )
        self.condition = 'E/godot   ( 123): ERROR: Condition "err != OK" is true. Returning: err'
        self.callsite = (
            'E/godot   ( 123):    at: initialize '
            '(drivers/vulkan/rendering_context_driver_vulkan.cpp:921)'
        )
        self.fallback = (
            'E/godot   ( 123): WARNING: Your device does not seem to support Vulkan, '
            'switching to OpenGL 3.'
        )
        self.shader = 'E/godot   ( 123): ERROR: SceneShaderGLES3: Program linking failed:'

    def test_only_expected_startup_errors_are_exempted(self) -> None:
        log = '\n'.join([self.missing, self.condition, self.callsite, self.fallback])
        self.assertEqual(unexpected_errors(log), [])

    def test_vulkan_error_without_fallback_is_not_exempted(self) -> None:
        self.assertEqual(unexpected_errors(self.missing), [self.missing])

    def test_shader_error_after_fallback_fails(self) -> None:
        self.assertEqual(unexpected_errors('\n'.join([self.fallback, self.shader])), [self.shader])

    def test_similar_condition_at_another_callsite_fails(self) -> None:
        log = '\n'.join([self.condition, 'E/godot ( 123): at: other_function', self.fallback])
        self.assertEqual(unexpected_errors(log), [self.condition])

    def test_threadtime_format_errors_are_not_hidden(self) -> None:
        shader = '11-06 15:14:47.680  2241  2250 E godot : ERROR: shader linking failed'
        self.assertEqual(unexpected_errors(shader), [shader])

    def test_threadtime_expected_fallback_is_exempted(self) -> None:
        log = '\n'.join([
            '11-06 15:14:46.781  2241  2250 E godot : ERROR: vkEnumeratePhysicalDevices reported zero accessible devices.',
            '11-06 15:14:46.781  2241  2250 E godot : WARNING: Your device does not seem to support Vulkan, switching to OpenGL 3.',
        ])
        self.assertEqual(unexpected_errors(log), [])

    def test_fatal_and_script_errors_fail(self) -> None:
        log = 'FATAL EXCEPTION: main\nE/godot ( 123): SCRIPT ERROR: bad script'
        self.assertEqual(len(unexpected_errors(log)), 2)


if __name__ == '__main__':
    unittest.main()
