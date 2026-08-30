import Darwin
import Foundation
import JugnuCore

enum ShellIdentity {
    static func current() -> AddonRunner.ShellIdentity {
        let pid = getpid()
        return AddonRunner.ShellIdentity(pid: pid, startTS: startTS(pid: pid) ?? 0)
    }

    static func startTS(pid: Int32) -> Double? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let rc = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        guard rc == 0 else { return nil }
        let tv = info.kp_proc.p_starttime
        return Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000
    }
}
