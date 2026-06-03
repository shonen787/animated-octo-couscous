//! malwin - root module exposed to consumers as `@import("malwin")`.
const std = @import("std");

test {
    std.testing.refAllDecls(@This());
}
