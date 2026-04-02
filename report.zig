const std = @import("std");
const load = @import("load.zig");
const transformer = @import("transformer.zig");
const feeder = @import("feeder.zig");
const motor = @import("motor.zig");

pub const ReportInput = struct {
    facility_name: []const u8,
    voltage_ll: f64,
    target_pf: f64,
    growth_margin: f64,
    feeder_length_m: f64,

    demand: load.DemandResult,
    breakdown: []const load.LoadDemand,
    selection: transformer.TransformerSelection,
    feed: feeder.FeederResult,
    candidates: []const feeder.CableCandidate,
    motor_screen: motor.MotorScreenResult,
};

// Builds the report into a Writer.Allocating buffer then flushes to a file using std.fs.File.Writer

pub fn writeReport(allocator: std.mem.Allocator, out_path: []const u8, r: ReportInput) !void {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();
    const w = &aw.writer;

    try buildHeader(w, r);
    try buildLoadSummary(w, r);
    try buildTransformerSizing(w, r);
    try buildFeederSizing(w, r);
    try buildMotorScreen(w, r);
    try sep(w);
    try w.print("Report complete.\n", .{});
}
