const std = @import("std");

/// Extract server.jar URL from HTML content using regex pattern
///
/// Args:
///   allocator: Memory allocator to use for string operations
///   content: The HTML content to search in
///
/// Returns:
///   The server.jar URL if found, or null if not found
pub fn extractServerJarUrl(allocator: std.mem.Allocator, content: []const u8) !?[]const u8 {
    // Find the first occurrence of the pattern
    if (std.mem.indexOf(u8, content, "https://piston-data.mojang.com/v1/objects/")) |start_index| {
        // Find the end of the URL (after server.jar)
        const remaining_content = content[start_index..];
        if (std.mem.indexOf(u8, remaining_content, "/server.jar")) |jar_index| {
            const url_end = start_index + jar_index + "/server.jar".len;
            const url = content[start_index..url_end];

            // Validate the URL matches our pattern
            if (std.mem.startsWith(u8, url, "https://piston-data.mojang.com/v1/objects/") and
                std.mem.endsWith(u8, url, "/server.jar"))
            {
                // Return a copy of the URL
                return try allocator.dupe(u8, url);
            }
        }
    }

    return null;
}

test "extractServerJarUrl with valid URL" {
    const html_content = "Some HTML content with a link to https://piston-data.mojang.com/v1/objects/abc123def456/server.jar and other content";
    const result = try extractServerJarUrl(std.testing.allocator, html_content);

    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("https://piston-data.mojang.com/v1/objects/abc123def456/server.jar", result.?);

    // Clean up
    std.testing.allocator.free(result.?);
}

test "extractServerJarUrl with no URL" {
    const html_content = "Some HTML content without any server.jar URL";
    const result = try extractServerJarUrl(std.testing.allocator, html_content);

    try std.testing.expect(result == null);
}

test "extractServerJarUrl with invalid URL" {
    const html_content = "Some HTML content with https://piston-data.mojang.com/v1/objects/abc123def456/invalid.jar";
    const result = try extractServerJarUrl(std.testing.allocator, html_content);

    try std.testing.expect(result == null);
}
