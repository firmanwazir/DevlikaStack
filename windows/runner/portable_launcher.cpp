#include <windows.h>
#include <shellapi.h>
#include <string>

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PWSTR pCmdLine, int nCmdShow) {
    wchar_t buffer[MAX_PATH];
    GetModuleFileNameW(NULL, buffer, MAX_PATH);
    std::wstring exePath(buffer);
    size_t pos = exePath.find_last_of(L"\\/");
    std::wstring baseDir = (pos != std::wstring::npos) ? exePath.substr(0, pos) : L".";

    std::wstring targetExe = baseDir + L"\\bin\\DevlikaStack.exe";
    std::wstring binDir = baseDir + L"\\bin";

    // Try normal execution first (as this launcher is already requireAdministrator)
    HINSTANCE hInst = ShellExecuteW(
        NULL,
        L"open",
        targetExe.c_str(),
        pCmdLine,
        binDir.c_str(),
        SW_SHOWNORMAL
    );

    // If needed, elevate explicitly
    if ((INT_PTR)hInst <= 32) {
        ShellExecuteW(
            NULL,
            L"runas",
            targetExe.c_str(),
            pCmdLine,
            binDir.c_str(),
            SW_SHOWNORMAL
        );
    }

    return 0;
}
