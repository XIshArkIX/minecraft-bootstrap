const std = @import("std");
const httpRequest = @import("http-request.zig");
const decompress = @import("decompress.zig");

/// CurseForge API response structure based on the Get Files Response schema
/// Reference: https://docs.curseforge.com/rest-api/#tocS_Get%20Files%20Response
pub const GetFilesResponse = struct {
    data: []FileData,
    pagination: ?Pagination = null,

    pub const FileData = struct {
        id: i32,
        gameId: i32,
        modId: i32,
        isAvailable: bool,
        displayName: []const u8,
        fileName: []const u8,
        releaseType: i32,
        fileStatus: i32,
        hashes: []FileHash,
        fileDate: []const u8,
        fileLength: i64,
        downloadCount: i64,
        fileSizeOnDisk: ?i64 = null,
        downloadUrl: ?[]const u8 = null,
        gameVersions: [][]const u8,
        sortableGameVersions: []SortableGameVersion,
        dependencies: []FileDependency,
        exposeAsAlternative: ?bool = null,
        parentProjectFileId: ?i32 = null,
        alternateFileId: ?i32 = null,
        isServerPack: ?bool = null,
        serverPackFileId: ?i32 = null,
        isEarlyAccessContent: ?bool = null,
        earlyAccessEndDate: ?[]const u8 = null,
        fileFingerprint: i64,
        modules: []FileModule,

        pub const FileHash = struct {
            value: []const u8,
            algo: i32,
        };

        pub const SortableGameVersion = struct {
            gameVersionName: []const u8,
            gameVersionPadded: []const u8,
            gameVersion: []const u8,
            gameVersionReleaseDate: []const u8,
            gameVersionTypeId: ?i32 = null,
        };

        pub const FileDependency = struct {
            modId: i32,
            relationType: i32,
        };

        pub const FileModule = struct {
            name: []const u8,
            fingerprint: i64,
        };
    };

    pub const Pagination = struct {
        index: i32,
        pageSize: i32,
        resultCount: i32,
        totalCount: i64,
    };
};

/// Parses CurseForge API response JSON into GetFilesResponse struct
///
/// Args:
///   allocator: Memory allocator for parsing
///   jsonData: Raw JSON response from CurseForge API
///
/// Returns:
///   Parsed GetFilesResponse structure
///
/// Errors:
///   - error.OutOfMemory: If allocation fails
///   - error.SyntaxError: If JSON is malformed
///   - error.UnexpectedToken: If JSON structure doesn't match expected schema
pub fn parseGetFilesResponse(allocator: std.mem.Allocator, jsonData: []const u8) !GetFilesResponse {
    const parsed = try std.json.parseFromSlice(GetFilesResponse, allocator, jsonData, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    return parsed.value;
}

/// Extracts the download URL from the first file in the response
///
/// Args:
///   response: Parsed GetFilesResponse structure
///
/// Returns:
///   Download URL string or null if not found
pub fn extractDownloadUrl(response: *const GetFilesResponse) ?[]const u8 {
    if (response.data.len == 0) return null;
    return response.data[0].downloadUrl;
}

test "parseGetFilesResponse with minimal data" {
    const allocator = std.testing.allocator;

    const testJson =
        \\{
        \\  "data": [
        \\    {
        \\      "id": 12345,
        \\      "gameId": 432,
        \\      "modId": 67890,
        \\      "isAvailable": true,
        \\      "displayName": "Test Modpack",
        \\      "fileName": "test-modpack-1.0.0.zip",
        \\      "releaseType": 1,
        \\      "fileStatus": 4,
        \\      "hashes": [],
        \\      "fileDate": "2023-12-01T10:00:00.000Z",
        \\      "fileLength": 1048576,
        \\      "downloadCount": 100,
        \\      "downloadUrl": "https://example.com/test-modpack.zip",
        \\      "gameVersions": ["1.21.1"],
        \\      "sortableGameVersions": [],
        \\      "dependencies": [],
        \\      "fileFingerprint": 123456789,
        \\      "modules": []
        \\    }
        \\  ]
        \\}
    ;

    const response = try parseGetFilesResponse(allocator, testJson);
    defer std.json.parseFree(GetFilesResponse, response, .{ .allocator = allocator });

    try std.testing.expect(response.data.len == 1);
    try std.testing.expect(response.data[0].id == 12345);
    try std.testing.expectEqualStrings("Test Modpack", response.data[0].displayName);
    try std.testing.expectEqualStrings("test-modpack-1.0.0.zip", response.data[0].fileName);

    const downloadUrl = extractDownloadUrl(&response);
    try std.testing.expect(downloadUrl != null);
    try std.testing.expectEqualStrings("https://example.com/test-modpack.zip", downloadUrl.?);
}

test "extractDownloadUrl with empty data" {
    const response = GetFilesResponse{
        .data = &[_]GetFilesResponse.FileData{},
    };

    const downloadUrl = extractDownloadUrl(&response);
    try std.testing.expect(downloadUrl == null);
}

/// CurseForge API client for fetching modpack files
pub const CurseForgeClient = struct {
    allocator: std.mem.Allocator,
    httpClient: httpRequest,
    apiToken: []const u8,

    const CURSEFORGE_API_BASE_URL = "https://api.curseforge.com";

    pub fn init(allocator: std.mem.Allocator, apiToken: []const u8) !CurseForgeClient {
        const httpClient = try httpRequest.init(allocator);
        return CurseForgeClient{
            .allocator = allocator,
            .httpClient = httpClient,
            .apiToken = apiToken,
        };
    }

    pub fn deinit(self: *CurseForgeClient) void {
        self.httpClient.deinit();
    }

    /// Fetches the latest modpack file from CurseForge API
    ///
    /// Args:
    ///   modpackId: CurseForge modpack ID
    ///
    /// Returns:
    ///   GetFilesResponse containing modpack file information
    ///
    /// Errors:
    ///   - error.OutOfMemory: If allocation fails
    ///   - error.HttpRequestFailed: If HTTP request fails
    ///   - error.InvalidApiResponse: If API response is invalid
    pub fn getLatestModpackFile(self: *CurseForgeClient, modpackId: []const u8) !GetFilesResponse {
        // Build API URL
        const url = try std.fmt.allocPrint(self.allocator, "{s}/v1/mods/{s}/files?pageIndex=0&pageSize=1&sort=dateCreated&sortDescending=true&removeAlphas=true", .{ CURSEFORGE_API_BASE_URL, modpackId });
        defer self.allocator.free(url);

        // Prepare headers with API key
        const apiKeyHeader = try std.fmt.allocPrint(self.allocator, "{s}", .{self.apiToken});
        defer self.allocator.free(apiKeyHeader);

        var headers = [_]std.http.Header{
            .{ .name = "x-api-key", .value = apiKeyHeader },
            .{ .name = "Accept", .value = "application/json" },
        };

        // Make HTTP request
        const response = self.httpClient.get(url, headers[0..]) catch |err| {
            std.log.err("Failed to fetch modpack files from CurseForge API: {any}", .{err});
            return error.HttpRequestFailed;
        };
        defer self.allocator.free(response.body);

        if (response.status != .ok) {
            std.log.err("CurseForge API returned HTTP status: {any}", .{response.status});
            return error.HttpRequestFailed;
        }

        const decompressedResponse = if (decompress.isGzipCompressed(response.body))
            decompress.decompressGzip(std.heap.page_allocator, response.body) catch |err| {
                std.debug.print("Decompression failed: ✗ ({any})\n", .{err});
                return error.DecompressionFailed;
            }
        else
            try std.heap.page_allocator.dupe(u8, response.body);
        defer std.heap.page_allocator.free(decompressedResponse);

        // Parse JSON response
        const parsedResponse = parseGetFilesResponse(self.allocator, decompressedResponse) catch |err| {
            std.log.err("Failed to parse CurseForge API response: {any}", .{err});
            return error.InvalidApiResponse;
        };

        return parsedResponse;
    }

    /// Downloads modpack file from the given URL
    ///
    /// Args:
    ///   downloadUrl: URL to download the modpack file from
    ///
    /// Returns:
    ///   Raw bytes of the downloaded modpack file
    ///
    /// Errors:
    ///   - error.OutOfMemory: If allocation fails
    ///   - error.HttpRequestFailed: If HTTP request fails
    pub fn downloadModpackFile(self: *CurseForgeClient, downloadUrl: []const u8) ![]u8 {
        const response = self.httpClient.get(downloadUrl, &.{}) catch |err| {
            std.log.err("Failed to download modpack file from URL: {s}, error: {any}", .{ downloadUrl, err });
            return error.HttpRequestFailed;
        };

        if (response.status != .ok) {
            std.log.err("Download request returned HTTP status: {any}", .{response.status});
            self.allocator.free(response.body);
            return error.HttpRequestFailed;
        }

        // Create a mutable copy of the response body for the caller
        const mutableCopy = try self.allocator.dupe(u8, response.body);
        self.allocator.free(response.body);
        return mutableCopy;
    }
};

test "CurseForgeClient initialization" {
    const allocator = std.testing.allocator;
    const testApiToken = "test-api-token";

    var client = try CurseForgeClient.init(allocator, testApiToken);
    defer client.deinit();

    try std.testing.expectEqualStrings(testApiToken, client.apiToken);
}
