//! malwin - root module exposed to consumers as `@import("malwin")`.

pub const defs = @import("definitions.zig");

pub const windows = defs.windows;
pub const HANDLE = defs.HANDLE;
pub const DWORD = defs.DWORD;

pub const ProcessStruct = defs.ProcessStruct;
pub const PROCESSENTRY32 = defs.PROCESSENTRY32;

pub const CreateToolhelp32Snapshot = defs.CreateToolhelp32Snapshot;
pub const Process32First = defs.Process32First;
pub const Process32Next = defs.Process32Next;
pub const OpenProcess = defs.OpenProcess;
pub const GetModuleHandleA = defs.GetModuleHandleA;
pub const GetProcAddress = defs.GetProcAddress;
pub const VirtualAllocEx = defs.VirtualAllocEx;
pub const WriteProcessMemory = defs.WriteProcessMemory;
pub const CreateRemoteThread = defs.CreateRemoteThread;
pub const CloseHandle = defs.CloseHandle;
pub const WaitForSingleObject = defs.WaitForSingleObject;
pub const GetExitCodeThread = defs.GetExitCodeThread;

pub const GetRemoteProcessHandle = defs.GetRemoteProcessHandle;
pub const waitForEnter = defs.waitForEnter;

test {
    @import("std").testing.refAllDecls(@This());
}
