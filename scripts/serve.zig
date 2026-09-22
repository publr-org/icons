//! `zig build serve`: the gallery at http://127.0.0.1:8092/.
const std = @import("std");
const http = @import("publr_http");

const App = http.Server(.{});

pub fn main(init: std.process.Init) u8 {
    return http.cli.serve(App, init, .{
        .setup = &setup,
        // The page is 110 KB; the library's default response cap is 32 KB.
        .defaults = .{ .port = 8092, .connections_max = 16, .response_bytes_max = 1 << 20 },
    });
}

fn setup(app: *App) !void {
    app.router().get("/", &page);
}

fn page(req: *http.Request, res: *http.Response, ctx: *App.Context) !void {
    _ = req;
    _ = try http.static.serve_file(".", "/index.html", res, ctx.arena, ctx.options.response_bytes_max);
}
