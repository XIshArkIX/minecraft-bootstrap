const std = @import("std");

/// Error for when environment variable is not found
pub const ErrEnvNotFound = error.EnvNotFound;

/// Gets an environment variable by name
///
/// Args:
///   allocator: Memory allocator to use for string operations
///   name: The name of the environment variable to retrieve
///   optional: If false, throws ErrEnvNotFound when variable is not found
///            If true, returns null if optional=true and not found
///
/// Returns:
///   The environment variable value as a string, or null if optional=true and not found
pub fn getEnv(allocator: std.mem.Allocator, name: []const u8, optional: bool) !?[]const u8 {
    const env_var = std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => {
            if (optional) {
                return null;
            } else {
                return ErrEnvNotFound;
            }
        },
        else => return err,
    };

    // Clean up the allocated memory
    defer allocator.free(env_var);

    // Return a copy of the string
    const result = allocator.dupe(u8, env_var) catch |err| {
        allocator.free(env_var);
        return err;
    };

    return result;
}

/// Alternative version that returns an owned string (caller must free)
///
/// Args:
///   allocator: Memory allocator to use for string operations
///   name: The name of the environment variable to retrieve
///   optional: If false, throws ErrEnvNotFound when variable is not found
///            If true, returns null if optional=true and not found
///
/// Returns:
///   The environment variable value as an owned string, or null if optional=true and not found
///   Caller is responsible for freeing the returned string
pub fn getEnvOwned(allocator: std.mem.Allocator, name: []const u8, optional: bool) !?[]u8 {
    const env_var = std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => {
            if (optional) {
                return null;
            } else {
                return ErrEnvNotFound;
            }
        },
        else => return err,
    };

    return env_var;
}

test "getEnv with existing variable" {
    const result = try getEnv(std.testing.allocator, "PATH", false);
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.len > 0);

    // Clean up
    if (result) |value| {
        std.testing.allocator.free(value);
    }
}

test "getEnv with non-existing variable - optional=false" {
    const result = getEnv(std.testing.allocator, "NON_EXISTENT_VAR", false);
    try std.testing.expectError(ErrEnvNotFound, result);
}

test "getEnv with non-existing variable - optional=true" {
    const result = try getEnv(std.testing.allocator, "NON_EXISTENT_VAR", true);
    try std.testing.expect(result == null);
}
