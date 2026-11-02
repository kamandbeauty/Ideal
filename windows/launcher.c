/* Parsigo — tiny native launcher for the portable Windows build.
 *
 * Why a compiled launcher instead of a .bat:
 *   - a .bat flashes a console window for a moment, a GUI-subsystem exe does not
 *   - Explorer can pin it, give it an icon and pass dropped files to it
 *   - no dependency on the console code page, which mangles Persian output
 *
 * It does exactly one thing: start the bundled pythonw.exe on
 * desktop\main.py, in the app folder, forwarding any arguments it was given.
 * If the bundled runtime is missing it says so in a message box rather than
 * failing silently (a windowed process has no console to print to).
 *
 * Build (see windows/build_portable.py):
 *   zig cc -target x86_64-windows-gnu -O2 -municode -Wl,--subsystem,windows \
 *          -o Parsigo.exe launcher.c
 */
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

#define APP_TITLE L"Parsigo"

static void fail(const wchar_t *what, const wchar_t *detail) {
    wchar_t msg[2048];
    _snwprintf(msg, 2047,
        L"%ls\n\n%ls\n\n"
        L"پوشهٔ برنامه باید شامل پوشهٔ «python» و فایل «desktop\\main.py» باشد.\n"
        L"اگر فایل‌ها را از حالت فشرده خارج کرده‌اید، کل پوشه را یک‌جا نگه دارید.",
        what, detail ? detail : L"");
    msg[2047] = 0;
    MessageBoxW(NULL, msg, APP_TITLE, MB_ICONERROR | MB_OK);
}

static int file_exists(const wchar_t *path) {
    DWORD attr = GetFileAttributesW(path);
    return attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY);
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE prev, PWSTR cmdline, int show) {
    (void)inst; (void)prev; (void)cmdline; (void)show;

    wchar_t exe[MAX_PATH * 2];
    DWORD n = GetModuleFileNameW(NULL, exe, MAX_PATH * 2);
    if (n == 0 || n >= MAX_PATH * 2) { fail(L"مسیر برنامه پیدا نشد.", NULL); return 1; }

    /* strip the file name -> the folder the exe lives in */
    for (DWORD i = n; i > 0; i--) {
        if (exe[i - 1] == L'\\' || exe[i - 1] == L'/') { exe[i - 1] = 0; break; }
    }

    wchar_t pythonw[MAX_PATH * 2], python[MAX_PATH * 2], script[MAX_PATH * 2];
    _snwprintf(pythonw, MAX_PATH * 2, L"%ls\\python\\pythonw.exe", exe);
    _snwprintf(python,  MAX_PATH * 2, L"%ls\\python\\python.exe",  exe);
    _snwprintf(script,  MAX_PATH * 2, L"%ls\\desktop\\main.py",    exe);

    const wchar_t *py = file_exists(pythonw) ? pythonw : (file_exists(python) ? python : NULL);
    if (!py) { fail(L"مفسر پایتون همراه برنامه پیدا نشد: python\\pythonw.exe", exe); return 2; }
    if (!file_exists(script)) { fail(L"فایل اصلی برنامه پیدا نشد: desktop\\main.py", exe); return 3; }

    /* command line: "<pythonw>" "<script>" <original args> */
    wchar_t *passed = GetCommandLineW();
    /* skip the exe token (quoted or not) to forward only real arguments */
    wchar_t *p = passed;
    if (*p == L'"') { p++; while (*p && *p != L'"') p++; if (*p == L'"') p++; }
    else { while (*p && *p != L' ' && *p != L'\t') p++; }
    while (*p == L' ' || *p == L'\t') p++;

    size_t need = wcslen(py) + wcslen(script) + wcslen(p) + 16;
    wchar_t *cmd = (wchar_t *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, need * sizeof(wchar_t));
    if (!cmd) { fail(L"حافظهٔ کافی در دسترس نیست.", NULL); return 4; }
    _snwprintf(cmd, need, L"\"%ls\" \"%ls\" %ls", py, script, p);

    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    if (!CreateProcessW(py, cmd, NULL, NULL, FALSE, 0, NULL, exe, &si, &pi)) {
        wchar_t detail[512];
        _snwprintf(detail, 511, L"CreateProcessW failed, error %lu", GetLastError());
        detail[511] = 0;
        fail(L"اجرای برنامه ممکن نشد.", detail);
        HeapFree(GetProcessHeap(), 0, cmd);
        return 5;
    }

    HeapFree(GetProcessHeap(), 0, cmd);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return 0;
}
