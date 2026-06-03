const std = @import("std");
const Io = std.Io;
pub const windows = std.os.windows;
pub const HANDLE = windows.HANDLE;
pub const DWORD = windows.DWORD;

pub const ProcessStruct = struct { dwProcessId: windows.DWORD, hProcess: ?windows.HANDLE };

pub extern fn CreateToolhelp32Snapshot(dwFlags: DWORD, th32ProcessID: DWORD) callconv(.winapi) HANDLE;
pub extern fn Process32First(hSnapshot: HANDLE, lppe: *PROCESSENTRY32) callconv(.winapi) windows.BOOL;
pub extern fn Process32Next(hSnapshot: HANDLE, lppe: *PROCESSENTRY32) callconv(.winapi) windows.BOOL;
pub extern fn OpenProcess(dwDesiredAccess: windows.DWORD, bInheritHandle: windows.BOOL, dwProcessId: windows.DWORD) callconv(.winapi) windows.HANDLE;
pub extern fn GetModuleHandleA(lpModuleName: windows.LPCSTR) callconv(.winapi) ?windows.HMODULE;
pub extern fn GetProcAddress(hModule: windows.HMODULE, lpProcName: windows.LPCSTR) callconv(.winapi) ?windows.FARPROC;
pub extern fn VirtualAllocEx(hProcess: windows.HANDLE, lpAddress: ?windows.LPVOID, dwSize: windows.SIZE_T, flAllocationType: windows.DWORD, flProtect: windows.DWORD) callconv(.winapi) ?windows.LPVOID;
pub extern fn WriteProcessMemory(hProcess: windows.HANDLE, lpBaseAddress: windows.LPVOID, lpBuffer: windows.LPCVOID, nSize: windows.SIZE_T, lpNumberOfBytesWritten: *windows.SIZE_T) callconv(.winapi) windows.BOOL;
pub extern fn CreateRemoteThread(hProcess: windows.HANDLE, lpThreadAttributes: ?*std.os.windows.SECURITY_ATTRIBUTES, dwStackSize: windows.SIZE_T, lpStartAddress: *const std.os.windows.THREAD_START_ROUTINE, lpParameter: ?windows.LPVOID, dwCreationFlags: windows.DWORD, lpThreadId: ?*windows.DWORD) callconv(.winapi) ?windows.HANDLE;
pub extern fn CloseHandle(hObject: windows.HANDLE) callconv(.winapi) windows.BOOL;
pub extern fn WaitForSingleObject(hHandle: windows.HANDLE, dwMilliseconds: windows.DWORD) callconv(.winapi) windows.DWORD;
pub extern fn GetExitCodeThread(hThread: windows.HANDLE, lpExitCode: *windows.DWORD) callconv(.winapi) windows.BOOL;

const LoadLibraryWFn = *const fn (windows.LPCWSTR) callconv(.winapi) ?windows.HMODULE;

pub const PROCESSENTRY32 = extern struct {
    dwSize: windows.DWORD,
    cntUsage: windows.DWORD,
    th32ProcessID: windows.DWORD,
    th32DefaultHeapID: windows.ULONG_PTR,
    th32ModuleID: windows.DWORD,
    cntThreads: windows.DWORD,
    th32ParentProcessID: windows.DWORD,
    pcPriClassBase: windows.LONG,
    dwFlags: windows.DWORD,
    szExeFile: [windows.MAX_PATH]u8, // CHAR[MAX_PATH] -> byte array
};

fn matchAndOpen(Proc: *const PROCESSENTRY32, szProcessName: []const u8, out: *ProcessStruct) bool {
    var buffer2: [windows.MAX_PATH]u8 = undefined;
    _ = std.ascii.lowerString(&buffer2, &Proc.szExeFile);
    const name = std.mem.sliceTo(&buffer2, 0);
    if (std.mem.eql(u8, name, szProcessName)) {
        out.dwProcessId = Proc.th32ProcessID;
        out.hProcess = OpenProcess(0x1FFFFF, windows.BOOL.FALSE, Proc.th32ProcessID);
        return true;
    }
    return false;
}
pub fn GetRemoteProcessHandle(szProcessName: []const u8) !ProcessStruct {
    var Proc: PROCESSENTRY32 = undefined;
    Proc.dwSize = @sizeOf(PROCESSENTRY32);
    var procStruct: ProcessStruct = undefined;
    procStruct.hProcess = null;

    const hSnapShot = CreateToolhelp32Snapshot(0x00000002, 0);
    defer _ = CloseHandle(hSnapShot);

    if (Process32First(hSnapShot, &Proc) != windows.BOOL.TRUE) {
        std.debug.print("Hmm...Something went wrong\n", .{});
        return procStruct;
    }

    // Evaluate the first entry too, then walk the rest.
    if (matchAndOpen(&Proc, szProcessName, &procStruct)) return procStruct;
    while (Process32Next(hSnapShot, &Proc) == windows.BOOL.TRUE) {
        if (matchAndOpen(&Proc, szProcessName, &procStruct)) break;
    }

    return procStruct;
}
pub fn waitForEnter(reader: *std.Io.Reader) !void {
    std.debug.print("Press Enter to continue...\n", .{});
    // Discard everything up to and including the next '\n' so leftover
    // characters from this line don't satisfy the next prompt instantly.
    _ = try reader.discardDelimiterInclusive('\n');
}

extern fn GetProcessId(Process: std.os.windows.HANDLE) std.os.windows.DWORD;
extern fn GetCurrentProcessId() std.os.windows.DWORD;
extern fn LoadLibraryA(lpLibFileName: std.os.windows.LPCSTR) std.os.windows.HANDLE;

extern fn VirtualProtect(lpAddress: std.os.windows.LPVOID, dwSize: std.os.windows.SIZE_T, flNewProtect: std.os.windows.DWORD, lpflOldProtect: *std.os.windows.DWORD) std.os.windows.BOOL;
extern fn CreateThread(lpThreadAttributes: ?*std.os.windows.SECURITY_ATTRIBUTES, dwStackSize: std.os.windows.SIZE_T, lpStartAddress: *const std.os.windows.THREAD_START_ROUTINE, lpParameter: ?*std.os.windows.LPVOID, dwCreationFlags: std.os.windows.DWORD, lpThreadId: ?*std.os.windows.DWORD) std.os.windows.HANDLE;
extern fn VirtualAlloc(lpAddress: ?std.os.windows.LPVOID, dwSize: std.os.windows.SIZE_T, flAllocationType: std.os.windows.DWORD, flProtect: std.os.windows.DWORD) std.os.windows.LPVOID;
extern fn GetProcessHeap() std.os.windows.HANDLE;
extern fn WaitForSingleObject(hHandle: std.os.windows.HANDLE, dwMilliseconds: std.os.windows.DWORD) std.os.windows.DWORD;

extern fn HeapFree(hHeap: std.os.windows.HANDLE, dwFlags: std.os.windows.DWORD, lpMem: std.os.windows.LPVOID) void;
