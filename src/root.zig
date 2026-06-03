//! malwin - root module exposed to consumers as `@import("malwin")`.
//!
pub const malwin = @import("definitions.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
