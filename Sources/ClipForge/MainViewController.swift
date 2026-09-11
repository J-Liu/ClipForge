import AppKit
import AVFoundation

class MainViewController: NSViewController {
    private let playerController = PlayerController()
    private let playerView = PlayerView()
    private let openButton = NSButton(title: "打开视频…", target: nil, action: nil)
    private let playButton = NSButton(title: "播放 / 暂停", target: nil, action: nil)

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        playerView.translatesAutoresizingMaskIntoConstraints = false
        openButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.translatesAutoresizingMaskIntoConstraints = false

        openButton.target = self
        openButton.action = #selector(openFile)
        playButton.target = self
        playButton.action = #selector(togglePlay)

        view.addSubview(playerView)
        view.addSubview(openButton)
        view.addSubview(playButton)

        NSLayoutConstraint.activate([
            // 播放器占据上方大部分区域
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: openButton.topAnchor, constant: -12),

            // 按钮放在底部
            openButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            openButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            playButton.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 12),
            playButton.centerYAnchor.constraint(equalTo: openButton.centerYAnchor)
        ])
    }

    @objc private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadVideo(url: url)
        }
    }

    private func loadVideo(url: URL) {
        playerController.load(url: url)
        playerView.attach(player: playerController.player)
        playerController.play()
    }

    @objc private func togglePlay() {
        playerController.togglePlay()
    }
}

