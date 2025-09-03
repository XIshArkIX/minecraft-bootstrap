const std = @import("std");
const utils = @import("playtime_minecraft_bootstrap").utils;

const getEnv = utils.getEnv.getEnv;
const validateSemver = utils.validateSemver.validateSemver;

const ServerType = enum {
    VANILLA,
    CURSEFORGE,

    pub fn fromString(str: []const u8) ?ServerType {
        if (std.mem.eql(u8, str, "VANILLA")) return .VANILLA;
        if (std.mem.eql(u8, str, "CURSEFORGE")) return .CURSEFORGE;
        return null;
    }

    pub fn toString(self: ServerType) []const u8 {
        return switch (self) {
            .VANILLA => "VANILLA",
            .CURSEFORGE => "CURSEFORGE",
        };
    }
};

var workingDir: []const u8 = undefined;
var version: []const u8 = undefined;
var serverType: ServerType = undefined;
var curseforgeApiToken: []const u8 = undefined;
var curseforgeModpackId: []const u8 = undefined;

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

    if (getEnv(std.heap.page_allocator, "TYPE", false)) |localType| {
        if (localType == null) {
            std.debug.print("TYPE: ✗\n", .{});
            return error.TypeNotSet;
        }

        // Parse TYPE value to enum
        if (ServerType.fromString(localType.?)) |parsedType| {
            serverType = parsedType;
            std.debug.print("TYPE: ✓\n", .{});
        } else {
            std.debug.print("TYPE: ✗ (must be VANILLA or CURSEFORGE)\n", .{});
            return error.InvalidTypeValue;
        }
    } else |err| {
        if (err == error.EnvNotFound) {
            std.debug.print("TYPE: ✗\n", .{});
            return error.TypeNotSet;
        }

        return err;
    }

    // CurseForge-specific environment variables
    if (serverType == .CURSEFORGE) {
        // Check for CURSEFORGE_API_TOKEN or CF_API_TOKEN
        if (getEnv(std.heap.page_allocator, "CURSEFORGE_API_TOKEN", true)) |localApiToken| {
            if (localApiToken == null) {
                // Try shorter version
                if (getEnv(std.heap.page_allocator, "CF_API_TOKEN", false)) |shortApiToken| {
                    if (shortApiToken == null) {
                        std.debug.print("CURSEFORGE_API_TOKEN: ✗\n", .{});
                        return error.CurseforgeApiTokenNotSet;
                    }
                    curseforgeApiToken = shortApiToken.?;
                    std.debug.print("CURSEFORGE_API_TOKEN: ✓\n", .{});
                } else |err| {
                    if (err == error.EnvNotFound) {
                        std.debug.print("CURSEFORGE_API_TOKEN: ✗\n", .{});
                        return error.CurseforgeApiTokenNotSet;
                    }
                    return err;
                }
            } else {
                curseforgeApiToken = localApiToken.?;
                std.debug.print("CURSEFORGE_API_TOKEN: ✓\n", .{});
            }
        } else |err| {
            if (err == error.EnvNotFound) {
                // Try shorter version
                if (getEnv(std.heap.page_allocator, "CF_API_TOKEN", false)) |shortApiToken| {
                    if (shortApiToken == null) {
                        std.debug.print("CURSEFORGE_API_TOKEN: ✗\n", .{});
                        return error.CurseforgeApiTokenNotSet;
                    }
                    curseforgeApiToken = shortApiToken.?;
                    std.debug.print("CURSEFORGE_API_TOKEN: ✓\n", .{});
                } else |shortErr| {
                    if (shortErr == error.EnvNotFound) {
                        std.debug.print("CURSEFORGE_API_TOKEN: ✗\n", .{});
                        return error.CurseforgeApiTokenNotSet;
                    }
                    return shortErr;
                }
            } else {
                return err;
            }
        }

        // Check for CURSEFORGE_MODPACK_ID or CF_MODPACK_ID
        if (getEnv(std.heap.page_allocator, "CURSEFORGE_MODPACK_ID", true)) |localModpackId| {
            if (localModpackId == null) {
                // Try shorter version
                if (getEnv(std.heap.page_allocator, "CF_MODPACK_ID", false)) |shortModpackId| {
                    if (shortModpackId == null) {
                        std.debug.print("CURSEFORGE_MODPACK_ID: ✗\n", .{});
                        return error.CurseforgeModpackIdNotSet;
                    }
                    curseforgeModpackId = shortModpackId.?;
                    std.debug.print("CURSEFORGE_MODPACK_ID: ✓\n", .{});
                } else |err| {
                    if (err == error.EnvNotFound) {
                        std.debug.print("CURSEFORGE_MODPACK_ID: ✗\n", .{});
                        return error.CurseforgeModpackIdNotSet;
                    }
                    return err;
                }
            } else {
                curseforgeModpackId = localModpackId.?;
                std.debug.print("CURSEFORGE_MODPACK_ID: ✓\n", .{});
            }
        } else |err| {
            if (err == error.EnvNotFound) {
                // Try shorter version
                if (getEnv(std.heap.page_allocator, "CF_MODPACK_ID", false)) |shortModpackId| {
                    if (shortModpackId == null) {
                        std.debug.print("CURSEFORGE_MODPACK_ID: ✗\n", .{});
                        return error.CurseforgeModpackIdNotSet;
                    }
                    curseforgeModpackId = shortModpackId.?;
                    std.debug.print("CURSEFORGE_MODPACK_ID: ✓\n", .{});
                } else |shortErr| {
                    if (shortErr == error.EnvNotFound) {
                        std.debug.print("CURSEFORGE_MODPACK_ID: ✗\n", .{});
                        return error.CurseforgeModpackIdNotSet;
                    }
                    return shortErr;
                }
            } else {
                return err;
            }
        }
    }
}

fn handleVanillaServer() !void {
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

fn handleCurseforgeServer() !void {
    std.debug.print("Setting up CurseForge modpack server...\n", .{});

    // Create EULA file first
    const eulaPath = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/eula.txt", .{workingDir});
    defer std.heap.page_allocator.free(eulaPath);
    const eulaFile = try std.fs.createFileAbsolute(eulaPath, .{});
    defer eulaFile.close();

    eulaFile.writeAll("eula=true\n") catch {
        std.debug.print("Failed to create EULA file: ✗\n", .{});
        return error.FailedToCreateEulaFile;
    };

    std.debug.print("EULA file created: ✓\n", .{});

    // Initialize CurseForge API client
    var curseforgeClient = try utils.curseforgeApi.CurseForgeClient.init(std.heap.page_allocator, curseforgeApiToken);
    defer curseforgeClient.deinit();

    // Test connection
    {
        std.debug.print("Testing connection to CurseForge API: ", .{});

        // We'll test the connection by making the actual API call
        // If it fails, we'll know the connection or API key is invalid
    }

    // Fetch modpack files from CurseForge API
    var modpackResponse: utils.curseforgeApi.GetFilesResponse = undefined;
    {
        std.debug.print("Fetching modpack files from CurseForge API: ", .{});

        modpackResponse = curseforgeClient.getLatestModpackFile(curseforgeModpackId) catch |err| {
            std.debug.print("✗ (API request failed: {any})\n", .{err});
            return error.CurseForgeApiFailed;
        };

        std.debug.print("✓\n", .{});
        std.debug.print("Testing connection to CurseForge API: ✓\n", .{});
    }

    // Extract download URL
    var downloadUrl: []const u8 = undefined;
    {
        std.debug.print("Extracting modpack download URL: ", .{});

        const extractedUrl = utils.curseforgeApi.extractDownloadUrl(&modpackResponse);
        if (extractedUrl == null) {
            std.debug.print("✗ (download URL not found in API response)\n", .{});
            return error.ModpackDownloadUrlNotFound;
        }

        downloadUrl = extractedUrl.?;
        std.debug.print("✓\n", .{});
        std.log.info("Modpack download URL: {s}", .{downloadUrl});
    }

    // Download modpack file
    var modpackData: []u8 = undefined;
    {
        std.debug.print("Downloading modpack file: ", .{});

        modpackData = curseforgeClient.downloadModpackFile(downloadUrl) catch |err| {
            std.debug.print("✗ (download failed: {any})\n", .{err});
            return error.ModpackDownloadFailed;
        };

        std.debug.print("✓\n", .{});
        std.log.info("Downloaded modpack file size: {} bytes", .{modpackData.len});
    }
    defer std.heap.page_allocator.free(modpackData);

    // Verify it's a ZIP file and extract
    {
        std.debug.print("Extracting modpack files: ", .{});

        if (!utils.decompress.isZipCompressed(modpackData)) {
            std.debug.print("✗ (downloaded file is not a ZIP archive)\n", .{});
            return error.InvalidModpackFormat;
        }

        utils.decompress.extractZip(std.heap.page_allocator, modpackData, workingDir) catch |err| {
            std.debug.print("✗ (extraction failed: {any})\n", .{err});
            return error.ModpackExtractionFailed;
        };

        std.debug.print("✓\n", .{});
    }

    // TODO: implement proper cleanup for parsed JSON in Zig 0.15.1

    std.debug.print("CurseForge modpack server setup completed successfully: ✓\n", .{});
}

pub fn main() !void {
    try ensureEnvs();

    switch (serverType) {
        .VANILLA => try handleVanillaServer(),
        .CURSEFORGE => try handleCurseforgeServer(),
    }
}
