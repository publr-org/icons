pub fn get(name: Name) []const u8 {
    const values = comptime blk: {
        const fields = @typeInfo(Name).@"enum".fields;
        var result: [fields.len][]const u8 = undefined;
        for (fields, 0..) |field, index| result[index] = @field(@This(), field.name);
        break :blk result;
    };
    return values[@intFromEnum(name)];
}
