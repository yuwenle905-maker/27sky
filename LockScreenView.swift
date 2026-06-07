// LockScreenView.swift — 生物识别 / 锁屏密码安全界面
import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @State private var isUnlocked = false
    @State private var authError: String?
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            if isUnlocked {
                MainTabView()
                    .transition(.opacity)
            } else {
                lockOverlay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isUnlocked)
        .onAppear { authenticate() }
        // 从后台唤醒时重新锁定
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            isUnlocked = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if !isUnlocked { authenticate() }
        }
    }

    private var lockOverlay: some View {
        ZStack {
            // 毛玻璃背景
            Color(.systemBackground)
                .ignoresSafeArea()

            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App图标区域
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "5B8CFF"), Color(hex: "A29BFE")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .shadow(color: Color(hex: "5B8CFF").opacity(0.4), radius: 16, x: 0, y: 8)

                    Text("💰")
                        .font(.system(size: 44))
                }

                VStack(spacing: 8) {
                    Text("随手记")
                        .font(.title.bold())
                    Text("需要验证身份才能访问")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let error = authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // 解锁按钮
                Button {
                    authenticate()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: biometricIcon)
                            .font(.title3)
                        Text(isAuthenticating ? "验证中..." : biometricLabel)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "5B8CFF"), Color(hex: "A29BFE")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Color(hex: "5B8CFF").opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 40)
                .disabled(isAuthenticating)
                .padding(.bottom, 60)
            }
        }
    }

    private var biometricIcon: String {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "lock.fill"
        }
        switch ctx.biometryType {
        case .faceID:   return "faceid"
        case .touchID:  return "touchid"
        default:        return "lock.fill"
        }
    }

    private var biometricLabel: String {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "输入密码解锁"
        }
        switch ctx.biometryType {
        case .faceID:  return "Face ID 解锁"
        case .touchID: return "Touch ID 解锁"
        default:       return "输入密码解锁"
        }
    }

    private func authenticate() {
        isAuthenticating = true
        authError = nil
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "使用锁屏密码"
        var error: NSError?

        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authError = "设备不支持身份验证"
            isAuthenticating = false
            return
        }

        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "验证身份以访问随手记") { success, err in
            DispatchQueue.main.async {
                isAuthenticating = false
                if success {
                    withAnimation { isUnlocked = true }
                } else {
                    if let e = err as? LAError {
                        switch e.code {
                        case .userCancel, .appCancel:
                            authError = "已取消，点击按钮重试"
                        case .biometryLockout:
                            authError = "生物识别已锁定，请使用锁屏密码"
                        default:
                            authError = "验证失败，请重试"
                        }
                    }
                }
            }
        }
    }
}
