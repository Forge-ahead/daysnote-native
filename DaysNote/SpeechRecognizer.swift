import Foundation
import Speech
import AVFoundation

/// 系统语音转文字：中文（zh-CN）实时识别，结果回填到「一句话管理事件」输入框。
/// 使用 iOS 内置 Speech 框架，不需要额外 API Key。
final class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?
    @Published var authorized = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()
    private var tapInstalled = false

    /// 系统回调不一定在主线程，所有界面状态统一回主线程更新。
    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }

    init() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            self?.onMain { self?.authorized = (status == .authorized) }
        }
    }

    func toggle() {
        if isRecording { stop() } else { start() }
    }

    func start() {
        guard !isRecording else { return }
        transcript = ""
        errorMessage = nil
        if authorized {
            requestMicAndBegin()
            return
        }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self else { return }
            self.onMain {
                self.authorized = (status == .authorized)
                if status == .authorized {
                    self.requestMicAndBegin()
                } else {
                    self.errorMessage = "语音识别未授权，请在系统设置中开启"
                }
            }
        }
    }

    private func requestMicAndBegin() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self else { return }
            self.onMain {
                if granted {
                    self.begin()
                } else {
                    self.errorMessage = "麦克风未授权，请在系统设置中开启"
                }
            }
        }
    }

    private func begin() {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "当前设备暂不支持语音识别"
            return
        }
        finish() // 清理上一次残留

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                req.append(buffer)
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()

            task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                self.onMain {
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if error != nil || result?.isFinal == true {
                        self.finish()
                    }
                }
            }
            isRecording = true
        } catch {
            errorMessage = "启动语音失败：\(error.localizedDescription)"
            finish()
        }
    }

    /// 主动停止：先让音频请求收尾，再释放资源。已实时转写的内容会保留。
    func stop() {
        request?.endAudio()
        finish()
    }

    private func finish() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning { engine.stop() }
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
    }
}
