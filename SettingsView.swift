// SettingsView.swift — 设置页面（含锁屏开关）
import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @AppStorage("lockEnabled") private var lockEnabled = false
    @State private var showDisableConfirm = false
    @State private var isVerifying = false

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        NavigationStack {
            List {
                // 安全设置
                Section {
                    HStack {
                        Label("锁屏保护", systemImage: "lock.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { lockEnabled },
                            set: { newVal in
                                if newVal {
                                    // 开启时验证一次身份
                                    authenticate { success in
                                        if success {
                                            lockEnabled = true
                                            haptic.impactOccurred()
                                        }
                                    }
                                } else {
                                    // 关闭时也需要验证一次身份
                                    authenticate { success in
                                        if success {
                                            lockEnabled = false
                                            haptic.impactOccurred()
                                        }
                                    }
                                }
                            }
                        ))
                    }

                    if lockEnabled {
                        HStack {
                            Image(systemName: biometricIcon)
                                .foregroundColor(.green)
                            Text("已启用 \(biometricLabel)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "lock.open.fill")
                                .foregroundColor(.secondary)
                            Text("未开启，任何人可直接进入")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("隐私与安全")
                } footer: {
                    Text("开启后每次打开或从后台唤醒 App 时，需要通过 Face ID / Touch ID 或锁屏密码验证。")
                }

                // 关于
                Section {
                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var biometricIcon: String {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "lock.fill"
        }
        switch ctx.biometryType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.fill"
        }
    }

    private var biometricLabel: String {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "锁屏密码"
        }
        switch ctx.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        default:       return "锁屏密码"
        }
    }

    private func authenticate(completion: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "使用锁屏密码"
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(true) // 设备不支持则直接允许
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "验证身份以修改锁屏设置") { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
