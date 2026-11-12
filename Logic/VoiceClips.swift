import Foundation

/// 自然な声の聞き流し音声（Gemini TTS・声 Fola で作った問題ごとの mp3）。
/// 1問につき `<id>_q.mp3`（問題＋選択肢）と `<id>_a.mp3`（正解＋解説）の2本。考える間はアプリ側で入れる。
/// 置き場所は音声専用のWorker。どの問題に音声があるかは index.json（資格ごとのIDの一覧）で知る。
/// 原稿の作り方：資格note音声試作/gemini_listen/build_scripts.py
enum VoiceClips {
    static let base = URL(string: "https://shikakunote-audio.beqd1106.workers.dev/")!

    enum Part: String { case question = "q", answer = "a" }

    static func url(exam: String, id: String, part: Part) -> URL {
        base.appendingPathComponent(exam).appendingPathComponent("\(id)_\(part.rawValue).mp3")
    }

    /// 設定「自然な声で聞く」（既定オン）
    static let settingKey = "listening.naturalVoice"
    static var enabled: Bool { UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true }

    /// 資格ごとの「音声がある問題ID」。前回取れた一覧を端末に残しておき、起動のたびに新しいものを取りにいく
    private static let lock = NSLock()
    private static var _index: [String: Set<String>] = loadCached()
    static var index: [String: Set<String>] {
        lock.lock(); defer { lock.unlock() }
        return _index
    }

    static func has(exam: String, id: String) -> Bool {
        enabled && (index[exam]?.contains(id) ?? false)
    }

    /// index.json を取りにいく。失敗しても前回の一覧のまま（オフラインでも落ちない）
    static func refresh(session: URLSession = .shared) async {
        var req = URLRequest(url: base.appendingPathComponent("index.json"))
        req.cachePolicy = .reloadRevalidatingCacheData
        req.timeoutInterval = 15
        guard let (data, res) = try? await session.data(for: req),
              (res as? HTTPURLResponse)?.statusCode == 200,
              let parsed = decode(data) else { return }
        lock.lock(); _index = parsed; lock.unlock()
        try? data.write(to: cacheURL, options: .atomic)
    }

    /// {"fe":["id1","id2"],...} を読む。形が違えば nil
    static func decode(_ data: Data) -> [String: Set<String>]? {
        guard let raw = try? JSONDecoder().decode([String: [String]].self, from: data) else { return nil }
        return raw.mapValues(Set.init)
    }

    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("voice_index.json")
    }

    private static func loadCached() -> [String: Set<String>] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [:] }
        return decode(data) ?? [:]
    }
}
