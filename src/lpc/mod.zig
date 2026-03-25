//! LPC — 本地过程调用端口（CSRSS / 子系统消息路径桩）。
//! 消息布局对齐 NT5 CSRSS API 思路的最小子集（供 SMSS/CSRSS 启动握手）。

const klog = @import("../rtl/klog.zig");

pub const csrss_api_port: []const u8 = "\\ZirconOS\\ApiPort";

pub const CsrssApiMsgType = enum(u32) {
    invalid = 0,
    client_connect = 1,
    client_ping = 2,
    register_gre = 3,
};

pub const CsrssApiMessage = extern struct {
    msg_type: u32,
    client_pid: u32,
    status: u32,
    reserved: u32 = 0,
};

var port_ready: bool = false;
var last_csrss_msg: CsrssApiMessage = .{
    .msg_type = 0,
    .client_pid = 0,
    .status = 0,
    .reserved = 0,
};

pub fn initExecutive() void {
    port_ready = true;
    klog.info("LPC: server port ready (CSRSS API stub)", .{});
}

pub fn isCsrssPortReady() bool {
    return port_ready;
}

/// CSRSS 用户态桩等价：向 API 端口登记图形运行时（GRE）就绪。
pub fn csrssRegisterGre(client_pid: u32) u32 {
    last_csrss_msg = .{
        .msg_type = @intFromEnum(CsrssApiMsgType.register_gre),
        .client_pid = client_pid,
        .status = 0,
    };
    klog.info("LPC: CSRSS register_gre pid=%u (stub)", .{client_pid});
    return 0;
}

pub fn csrssClientHello(client_pid: u32) u32 {
    last_csrss_msg = .{
        .msg_type = @intFromEnum(CsrssApiMsgType.client_connect),
        .client_pid = client_pid,
        .status = 0,
    };
    klog.info("LPC: CSRSS client_connect pid=%u (ApiPort)", .{client_pid});
    return 0;
}

pub fn lastMessage() CsrssApiMessage {
    return last_csrss_msg;
}

pub fn initStub() void {
    initExecutive();
}
