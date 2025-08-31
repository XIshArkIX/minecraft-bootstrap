const std = @import("std");

pub fn validateSemver(version_str: []const u8) bool {
    // Basic semver validation: X.Y.Z where X, Y, Z are numbers
    var parts = std.mem.splitScalar(u8, version_str, '.');
    var count: u8 = 0;

    while (parts.next()) |part| {
        count += 1;
        if (count > 3) return false; // Too many parts

        // Check if part is a valid number
        if (part.len == 0) return false; // Empty part
        for (part) |char| {
            if (char < '0' or char > '9') {
                return false; // Non-numeric character
            }
        }
    }

    return count == 3; // Must have exactly 3 parts
}
