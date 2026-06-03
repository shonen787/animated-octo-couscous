const std = @import("std");
//const Io = std.Io;
/// Alias for `std.os.windows`; re-exported for convenience.
pub const windows = std.os.windows;
/// Win32 opaque kernel object handle (`*anyopaque`).
pub const HANDLE = windows.HANDLE;
/// Win32 32-bit unsigned integer (`u32`).
pub const DWORD = windows.DWORD;

pub const TH32CS_SNAPPROCESS = 0x00000002;

/// Result bundle for `GetRemoteProcessHandle`: the target PID and an open handle (or null on miss).
pub const ProcessStruct = struct {
    /// Target process identifier (PID).
    dwProcessId: windows.DWORD,
    /// Handle opened via `OpenProcess` with PROCESS_ALL_ACCESS, or `null` if not found.
    hProcess: ?windows.HANDLE,
};

/// Take a snapshot of system processes/threads/modules. Pass `TH32CS_SNAPPROCESS` (0x2) to enumerate processes.
pub extern fn CreateToolhelp32Snapshot(dwFlags: DWORD, th32ProcessID: DWORD) callconv(.winapi) HANDLE;
/// Retrieve information about the first process in a toolhelp snapshot. `lppe.dwSize` must be set first.
pub extern fn Process32First(hSnapshot: HANDLE, lppe: *PROCESSENTRY32) callconv(.winapi) windows.BOOL;
/// Retrieve information about the next process in a toolhelp snapshot. Returns FALSE when iteration ends.
pub extern fn Process32Next(hSnapshot: HANDLE, lppe: *PROCESSENTRY32) callconv(.winapi) windows.BOOL;
/// Open a handle to an existing process by PID with the requested access mask.
pub extern fn OpenProcess(dwDesiredAccess: windows.DWORD, bInheritHandle: windows.BOOL, dwProcessId: windows.DWORD) callconv(.winapi) windows.HANDLE;
/// Retrieve a handle to a module already loaded in the calling process (ANSI name).
pub extern fn GetModuleHandleA(lpModuleName: windows.LPCSTR) callconv(.winapi) ?windows.HMODULE;
/// Resolve the address of an exported symbol (function or variable) from a loaded module.
pub extern fn GetProcAddress(hModule: windows.HMODULE, lpProcName: windows.LPCSTR) callconv(.winapi) ?windows.FARPROC;
/// Reserve and/or commit a region of memory inside a remote process's virtual address space.
pub extern fn VirtualAllocEx(hProcess: windows.HANDLE, lpAddress: ?windows.LPVOID, dwSize: windows.SIZE_T, flAllocationType: windows.DWORD, flProtect: windows.DWORD) callconv(.winapi) ?windows.LPVOID;
/// Write `nSize` bytes from `lpBuffer` into a remote process at `lpBaseAddress`.
pub extern fn WriteProcessMemory(hProcess: windows.HANDLE, lpBaseAddress: windows.LPVOID, lpBuffer: windows.LPCVOID, nSize: windows.SIZE_T, lpNumberOfBytesWritten: *windows.SIZE_T) callconv(.winapi) windows.BOOL;
/// Create a thread that runs in the address space of another process.
pub extern fn CreateRemoteThread(hProcess: windows.HANDLE, lpThreadAttributes: ?*std.os.windows.SECURITY_ATTRIBUTES, dwStackSize: windows.SIZE_T, lpStartAddress: *const std.os.windows.THREAD_START_ROUTINE, lpParameter: ?windows.LPVOID, dwCreationFlags: windows.DWORD, lpThreadId: ?*windows.DWORD) callconv(.winapi) ?windows.HANDLE;
/// Close a kernel object handle (process, thread, snapshot, etc.).
pub extern fn CloseHandle(hObject: windows.HANDLE) callconv(.winapi) windows.BOOL;
/// Block until `hHandle` is signaled or `dwMilliseconds` elapses (`INFINITE` = 0xFFFFFFFF).
pub extern fn WaitForSingleObject(hHandle: windows.HANDLE, dwMilliseconds: windows.DWORD) callconv(.winapi) windows.DWORD;
/// Read the exit code of a (typically terminated) thread into `lpExitCode`.
pub extern fn GetExitCodeThread(hThread: windows.HANDLE, lpExitCode: *windows.DWORD) callconv(.winapi) windows.BOOL;

const LoadLibraryWFn = *const fn (windows.LPCWSTR) callconv(.winapi) ?windows.HMODULE;

/// Win32 PROCESSENTRY32 record returned by `Process32First`/`Process32Next`.
pub const PROCESSENTRY32 = extern struct {
    /// Size of this struct in bytes; must be initialized to `@sizeOf(PROCESSENTRY32)` before first use.
    dwSize: windows.DWORD,
    /// Reserved / no longer used.
    cntUsage: windows.DWORD,
    /// Process identifier (PID).
    th32ProcessID: windows.DWORD,
    /// Reserved / no longer used.
    th32DefaultHeapID: windows.ULONG_PTR,
    /// Reserved / no longer used.
    th32ModuleID: windows.DWORD,
    /// Number of threads in the process.
    cntThreads: windows.DWORD,
    /// PID of the parent process.
    th32ParentProcessID: windows.DWORD,
    /// Base priority of any threads created by this process.
    pcPriClassBase: windows.LONG,
    /// Reserved.
    dwFlags: windows.DWORD,
    /// Null-terminated executable file name (ANSI), no path.
    szExeFile: [windows.MAX_PATH]u8, // CHAR[MAX_PATH] -> byte array
};

pub fn matchAndOpen(Proc: *const PROCESSENTRY32, szProcessName: []const u8, out: *ProcessStruct) bool {
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
/// Walks a process snapshot and returns a `ProcessStruct` for the first match of `szProcessName`
/// (case-insensitive, basename only). `hProcess` is `null` if no match is found.
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
/// Prints a "Press Enter to continue..." prompt and consumes input from `reader` up to and
/// including the next newline. Useful for pausing CLI tools between stages.
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

extern fn HeapFree(hHeap: std.os.windows.HANDLE, dwFlags: std.os.windows.DWORD, lpMem: std.os.windows.LPVOID) void;
