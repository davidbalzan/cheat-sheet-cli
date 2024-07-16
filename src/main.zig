const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = struct {
    key: []const u8,
    description: []const u8,
};

const Category = struct {
    category: []const u8,
    bindings: []Entry,
};

const CheatSheet = struct {
    categories: []Category,
};

pub fn renderCategoryTitle(category: Category) !void {
    const startLine = " -- 📂  ";

    std.debug.print("\x1b[33m\x1b[1m{s} {s:-^85}\x1b[0m\x1b[0m\n", .{ startLine, category.category });
}

pub fn renderBinding(entry: Entry) !void {
    std.debug.print("\x1b[1m{s: <30}\x1b[0m ", .{entry.key});
    std.debug.print("  {s}\n", .{entry.description});
}

const os = @import("std").os;

pub fn createFile(fullPath: []const u8) !?std.fs.File {
    var newFile: ?std.fs.File = null;
    newFile = std.fs.cwd().createFile(fullPath, .{
        .exclusive = true, // This ensures the file is created only if it does not exist
    }) catch |e| {
        switch (e) {
            error.PathAlreadyExists => {
                return null;
            },
            else => return e, // Propagate other errors
        }
    };

    return newFile;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const allocator: Allocator = gpa.allocator();

    const envvar_name = "HOME";

    const envvar = try std.process.getEnvVarOwned(allocator, envvar_name);
    defer allocator.free(envvar);

    // Resolve the home directory
    const home = envvar;

    const directory = try std.fmt.allocPrint(allocator, "{s}/.local/share/cheat-sheet/", .{home});
    const fullPath = try std.fmt.allocPrint(allocator, "{s}/.local/share/cheat-sheet/cheat-sheet.json", .{home});

    // ensure file and follder is present
    try std.fs.cwd().makePath(directory);

    // Attempt to create the file, handling the case where the file might already exist
    const newFile = try createFile(fullPath);

    // If the file was newly created, write the initial JSON structure to it
    if (newFile) |f| {
        defer f.close(); // Ensure the file is closed when we're done with it
        const writer = f.writer();
        try writer.writeAll("{ \"categories\": [] }"); // Write initial JSON structure
        std.log.info("created new file at {s}. please enter your bindings there. ", .{fullPath});
    }

    const data = try std.fs.cwd().readFileAlloc(allocator, fullPath, 51200);
    defer allocator.free(data);

    const parsed = try std.json.parseFromSlice(CheatSheet, allocator, data, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const cheat_sheet = parsed.value;

    for (cheat_sheet.categories) |category| {
        try renderCategoryTitle(category);

        for (category.bindings) |entry| {
            try renderBinding(entry);
        }
        std.debug.print(" \n", .{});
    }
}
