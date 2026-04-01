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
var disk_driver: DRIVER_OBJECT = undefined;
var disk_device: DEVICE_OBJECT = undefined;

fn diskDispatch(_: *DEVICE_OBJECT, irp: *IRP) callconv(.c) u32 {
    klog.debug("IO: virtio-blk/AHCI FDO IRP major=%u (stub)", .{irp.major});
    return IO_STATUS_SUCCESS;
}

pub fn IoAttachDeviceToDeviceStack(upper: *DEVICE_OBJECT, lower: *DEVICE_OBJECT) ?*DEVICE_OBJECT {
    _ = .{ upper, lower };
    klog.debug("IO: IoAttachDeviceToDeviceStack stub", .{});
    return null;
}

pub fn initExecutive() void {
    video_driver = .{ .dispatch = videoDispatch };
    video_device = .{ .name = "\\Zircon\\Device\\Video0", .driver = &video_driver };
    disk_driver = .{ .dispatch = diskDispatch };
    disk_device = .{ .name = "\\Zircon\\Device\\Harddisk0", .driver = &disk_driver };
    klog.info("IO: IoMgr + Video0 + Harddisk0 FDO (IRP dispatch stubs)", .{});

    var probe: IRP = .{ .major = 0x18, .minor = 0 }; // IRP_MJ_INTERNAL_DEVICE_CONTROL placeholder
    _ = IoCallDriver(&video_device, &probe);
    var disk_irp: IRP = .{ .major = 0x03, .minor = 0 }; // read placeholder
    _ = IoCallDriver(&disk_device, &disk_irp);
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
