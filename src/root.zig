//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

// Export the utils module
pub const utils = @import("utils.zig");
