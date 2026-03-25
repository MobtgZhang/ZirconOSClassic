//! I/O Manager（io）— 设备对象、驱动、IRP（NT 5.x 最小路径）。

const klog = @import("../rtl/klog.zig");

pub const IO_STATUS_SUCCESS: u32 = 0;

pub const IRP = struct {
    major: u8,
    minor: u8,
    status: u32 = IO_STATUS_SUCCESS,
};

pub const DRIVER_OBJECT = struct {
    dispatch: ?*const fn (*DEVICE_OBJECT, *IRP) callconv(.c) u32 = null,
};

pub const DEVICE_OBJECT = struct {
    name: []const u8,
    driver: *DRIVER_OBJECT,
};

fn videoDispatch(_: *DEVICE_OBJECT, irp: *IRP) callconv(.c) u32 {
    klog.debug("IO: video FDO IRP major=%u", .{irp.major});
    return IO_STATUS_SUCCESS;
}

var video_driver: DRIVER_OBJECT = undefined;
var video_device: DEVICE_OBJECT = undefined;

pub fn initExecutive() void {
    video_driver = .{ .dispatch = videoDispatch };
    video_device = .{ .name = "\\Device\\Video0", .driver = &video_driver };
    klog.info("IO: IoMgr + Video0 FDO (IRP dispatch stub)", .{});

    var probe: IRP = .{ .major = 0x18, .minor = 0 }; // IRP_MJ_INTERNAL_DEVICE_CONTROL placeholder
    _ = IoCallDriver(&video_device, &probe);
}

pub fn IoCallDriver(dev: *DEVICE_OBJECT, irp: *IRP) u32 {
    const d = dev.driver.dispatch orelse return 0xC0000001;
    return d(dev, irp);
}

pub fn videoDevice() *DEVICE_OBJECT {
    return &video_device;
}

pub fn initStub() void {
    initExecutive();
}
