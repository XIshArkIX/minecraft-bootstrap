const std = @import("std");
const utils = @import("playtime_minecraft_bootstrap").utils;

const getEnv = utils.getEnv.getEnv;

var workingDir: []const u8 = undefined;
var version: []const u8 = undefined;

fn validateSemver(version_str: []const u8) bool {
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

fn ensureEnvs() !void {
    if (getEnv(std.heap.page_allocator, "EULA", false)) |localEula| {
        if (!std.mem.eql(u8, localEula.?, "true")) {
            std.debug.print("EULA: ✗\n", .{});
            return error.EULANotAccepted;
        }
        std.debug.print("EULA: ✓\n", .{});
    } else |err| {
        if (err == error.EnvNotFound) {
            std.debug.print("EULA: ✗\n", .{});
            return error.EULANotSet;
        }

        return err;
    }
    if (getEnv(std.heap.page_allocator, "VERSION", false)) |localVersion| {
        if (localVersion == null) {
            std.debug.print("VERSION: ✗\n", .{});
            return error.VersionNotSet;
        }

        // Validate semver format
        if (!validateSemver(localVersion.?)) {
            std.debug.print("VERSION: ✗ (invalid semver format)\n", .{});
            return error.InvalidVersionFormat;
        }

        version = localVersion.?;
        std.debug.print("VERSION: ✓\n", .{});
    } else |err| {
        if (err == error.EnvNotFound) {
            std.debug.print("VERSION: ✗\n", .{});
            return error.VersionNotSet;
        }

        return err;
    }

    if (getEnv(std.heap.page_allocator, "WORKING_DIR", false)) |localWorkingDir| {
        if (localWorkingDir == null) {
            std.debug.print("WORKING_DIR: ✗\n", .{});
            return error.PathNotSet;
        }

        if (!std.fs.path.isAbsolute(localWorkingDir.?)) {
            std.debug.print("WORKING_DIR: ✗\n", .{});
            return error.PathNotAbsolute;
        }

        workingDir = localWorkingDir.?;
        std.debug.print("WORKING_DIR: ✓\n", .{});
    } else |err| {
        if (err == error.EnvNotFound) {
            std.debug.print("WORKING_DIR: ✗\n", .{});
            return error.PathNotSet;
        }

        return err;
    }
}

pub fn main() !void {
    try ensureEnvs();

    const eula_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/eula.txt", .{workingDir});
    defer std.heap.page_allocator.free(eula_path);
    const eula_file = try std.fs.createFileAbsolute(eula_path, .{});
    defer eula_file.close();

    eula_file.writeAll("eula=true\n") catch {
        std.debug.print("Failed to create EULA file: ✗\n", .{});
        return error.FailedToCreateEulaFile;
    };

    std.debug.print("EULA file created: ✓\n", .{});

    var mcdownloader = try utils.httpRequest.init(std.heap.page_allocator);
    defer mcdownloader.deinit();

    // Test connection
    {
        std.debug.print("Testing connection to httpbin.org: ", .{});

        const response = mcdownloader.get("http://httpbin.org/get", &.{}) catch |err| {
            std.debug.print("✗ (connection failed: {any})\n", .{err});
            return error.ConnectionTestFailed;
        };
        defer std.heap.page_allocator.free(response.body);

        if (response.status != .ok) {
            std.debug.print("✗ (HTTP status: {any})\n", .{response.status});
            return error.ConnectionTestFailed;
        }

        std.debug.print("✓\n", .{});
    }

    var serverJarUrl = try std.ArrayList(u8).initCapacity(std.heap.page_allocator, 128);
    defer serverJarUrl.deinit(std.heap.page_allocator);

    // Fetch download URL for server.jar
    {
        std.debug.print("Fetching download URL: ", .{});

        const url = try std.fmt.allocPrint(std.heap.page_allocator, "https://mcversions.net/download/{s}", .{version});
        defer std.heap.page_allocator.free(url);

        const response = mcdownloader.get(url, &.{}) catch |err| {
            std.debug.print("✗ (request failed: {any})\n", .{err});
            return error.FetchUrlFailed;
        };
        defer std.heap.page_allocator.free(response.body);

        if (response.status != .ok) {
            std.debug.print("✗ (HTTP status: {any})\n", .{response.status});
            return error.FetchUrlFailed;
        }

        std.debug.print("✓\n", .{});

        // Try to decompress if it's compressed, otherwise use raw body
        const decompressedResponse = if (utils.decompress.isGzipCompressed(response.body))
            utils.decompress.decompressGzip(std.heap.page_allocator, response.body) catch |err| {
                std.debug.print("Decompression failed: ✗ ({any})\n", .{err});
                return error.DecompressionFailed;
            }
        else
            try std.heap.page_allocator.dupe(u8, response.body);
        defer std.heap.page_allocator.free(decompressedResponse);

        std.debug.print("Extracting server.jar URL: ", .{});

        const extractedServerJarUrl = utils.extractServerJarUrl.extractServerJarUrl(std.heap.page_allocator, decompressedResponse) catch |err| {
            std.debug.print("✗ (extraction failed: {any})\n", .{err});
            return error.UrlExtractionFailed;
        };

        if (extractedServerJarUrl == null) {
            std.debug.print("✗ (URL not found in response)\n", .{});
            return error.ServerJarUrlNotFound;
        }

        std.debug.print("✓\n", .{});

        try serverJarUrl.appendSlice(std.heap.page_allocator, extractedServerJarUrl.?);
        defer std.heap.page_allocator.free(extractedServerJarUrl.?);

        std.log.info("Server.jar URL: {s}", .{serverJarUrl.items});
    }

    // Download server.jar
    {
        std.debug.print("Downloading server.jar: ", .{});

        const response = mcdownloader.get(serverJarUrl.items, &.{}) catch |err| {
            std.debug.print("✗ (download failed: {any})\n", .{err});
            return error.ServerJarDownloadFailed;
        };
        defer std.heap.page_allocator.free(response.body);

        if (response.status != .ok) {
            std.debug.print("✗ (HTTP status: {any})\n", .{response.status});
            return error.ServerJarDownloadFailed;
        }

        std.debug.print("✓\n", .{});

        const serverJarPath = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/server.jar", .{workingDir});
        defer std.heap.page_allocator.free(serverJarPath);

        const serverJarFile = std.fs.createFileAbsolute(serverJarPath, .{}) catch |err| {
            std.debug.print("Failed to create server.jar file: ✗ ({any})\n", .{err});
            return error.FailedToCreateServerJarFile;
        };
        defer serverJarFile.close();

        // Check if response is compressed and decompress if needed
        const finalData = if (utils.decompress.isGzipCompressed(response.body))
            utils.decompress.decompressGzip(std.heap.page_allocator, response.body) catch |err| {
                std.debug.print("Failed to decompress server.jar: ✗ ({any})\n", .{err});
                return error.ServerJarDecompressionFailed;
            }
        else
            response.body;

        if (utils.decompress.isGzipCompressed(response.body)) {
            defer std.heap.page_allocator.free(finalData);
        }

        serverJarFile.writeAll(finalData) catch |err| {
            std.debug.print("Failed to write server.jar: ✗ ({any})\n", .{err});
            return error.FailedToWriteServerJar;
        };

        std.debug.print("Server.jar downloaded: ✓\n", .{});
    }
}
