// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

// MARK: - English

let enStrings: [String: String] = [
    // Settings - Tabs
    "settings.tab.general": "General",
    "settings.tab.recording": "Recording",
    "settings.tab.editing": "Editing",

    // Settings - General
    "settings.general.language": "Language",
    "settings.general.quitAfterLastWindow": "Quit after closing the last window",
    "settings.general.dontHideWindow": "Don't hide the main window during recording",
    "settings.general.countdown": "Countdown before recording",
    "settings.general.countdown.none": "None",
    "settings.general.countdown.3seconds": "3 seconds",
    "settings.general.countdown.5seconds": "5 seconds",

    // Settings - Recording
    "settings.recording.defaultMode": "Default Mode",
    "settings.recording.mode": "Recording mode",
    "settings.recording.mode.fullScreen": "Full Screen",
    "settings.recording.mode.window": "Window",
    "settings.recording.mode.region": "Region",
    "settings.recording.buttonStyle": "Button style",
    "settings.recording.buttonStyle.modePicker": "Pick mode, then press",
    "settings.recording.buttonStyle.directAction": "Menu items start directly",
    "settings.recording.audio": "Audio",
    "settings.recording.captureSystemAudio": "Capture system audio",
    "settings.recording.captureMicrophone": "Capture microphone",
    "settings.recording.microphoneGain": "Microphone gain",
    "settings.recording.video": "Video",
    "settings.recording.frameRate": "Frame rate",
    "settings.recording.codec": "Codec",
    "settings.recording.format": "Format",
    "settings.recording.showCursor": "Show cursor",
    "settings.recording.window": "Window",
    "settings.recording.dontHideMainWindow": "Don't hide main window during recording",
    "settings.recording.outputFolder": "Output Folder",
    "settings.recording.choose": "Choose…",
    "settings.recording.reveal": "Reveal",
    "settings.recording.30fps": "30 fps",
    "settings.recording.60fps": "60 fps",
    "settings.recording.h264": "H.264",
    "settings.recording.h265": "H.265 / HEVC",
    "settings.recording.mp4": "MP4",
    "settings.recording.mov": "MOV",

    // Settings - Editing
    "settings.editing.playback": "Playback",
    "settings.editing.autoPlay": "Auto-play when opening a video",
    "settings.editing.playbackEnd": "When playback ends",
    "settings.editing.playbackEnd.restart": "Restart from beginning",
    "settings.editing.playbackEnd.next": "Play next in folder",
    "settings.editing.playbackEnd.stop": "Stop",
    "settings.editing.export": "Export",
    "settings.editing.resolution": "Resolution",
    "settings.editing.frameRate": "Frame rate",
    "settings.editing.format": "Format",

    // Export Options
    "export.resolution": "Resolution",
    "export.frameRate": "Frame rate",
    "export.format": "Format",
    "export.original": "Original",
    "export.1080p": "1080p",
    "export.720p": "720p",
    "export.480p": "480p",
    "export.30fps": "30 fps",
    "export.60fps": "60 fps",
    "export.mp4h264": "MP4 (H.264)",
    "export.mp4h265": "MP4 (H.265)",
    "export.mov": "MOV",

    // Menu - App
    "menu.app.about": "About %@",
    "menu.app.checkForUpdates": "Check for Updates…",
    "menu.app.settings": "Settings…",
    "menu.app.hide": "Hide %@",
    "menu.app.hideOthers": "Hide Others",
    "menu.app.showAll": "Show All",
    "menu.app.quit": "Quit %@",

    // Menu - File
    "menu.file": "File",
    "menu.file.newWindow": "New Window",
    "menu.file.open": "Open…",
    "menu.file.appendVideo": "Append Video…",
    "menu.file.export": "Export…",
    "menu.file.close": "Close",

    // Menu - Edit
    "menu.edit": "Edit",
    "menu.edit.undo": "Undo",
    "menu.edit.redo": "Redo",
    "menu.edit.cut": "Cut",
    "menu.edit.copy": "Copy",
    "menu.edit.paste": "Paste",
    "menu.edit.selectAll": "Select All",

    // Menu - Playback
    "menu.playback": "Playback",
    "menu.playback.playPause": "Play/Pause",
    "menu.playback.mute": "Mute",
    "menu.playback.volumeUp": "Volume Up",
    "menu.playback.volumeDown": "Volume Down",
    "menu.playback.back1Frame": "Back 1 Frame",
    "menu.playback.forward1Frame": "Forward 1 Frame",
    "menu.playback.back5Seconds": "Back 5 Seconds",
    "menu.playback.forward5Seconds": "Forward 5 Seconds",

    // Menu - Record
    "menu.record": "Record",
    "menu.record.fullScreen": "Full Screen",
    "menu.record.window": "Window",
    "menu.record.region": "Region",
    "menu.record.start": "Start Recording",

    // Menu - Window
    "menu.window": "Window",
    "menu.window.minimize": "Minimize",
    "menu.window.zoom": "Zoom",

    // Main UI
    "main.tooltip.open": "Open video (⌘O)",
    "main.tooltip.play": "Play / Pause (Space)",
    "main.tooltip.scrub": "Drag to scrub through the timeline",
    "main.tooltip.setCutPoint": "Add cut point at the current position",
    "main.tooltip.export": "Export (⌘E)",
    "main.tooltip.record": "Start recording (⌘R)",
    "main.tooltip.recordMode": "Choose recording mode",
    "main.tooltip.volume": "Volume",
    "main.tooltip.mute": "Mute / Unmute (⇧⌘M)",
    "main.tooltip.dontHide": "Keep the main window visible while recording",
    "main.tooltip.crop": "Drag to crop. Press Esc to reset.",
    "main.tooltip.timeline": "Click to add a cut point. Right-click a segment to keep/remove it. Double-click a cut point to delete.",
    "main.dontHide": "Don't hide",

    // Errors
    "error.noVideoLoaded": "No video loaded",
    "error.noKeptSegments": "Nothing to export",
    "error.trackLoadFailed": "Failed to load video track: %@",
    "error.exportFailed": "Export failed: %@",
    "error.exportCancelled": "Export cancelled",
    "error.recordingFailed": "Recording failed: %@",
    "error.screenRecordingPermissionDenied": "Screen recording permission denied",
    "error.microphonePermissionDenied": "Microphone permission denied",
    "error.outputDirectoryNotWritable": "Cannot write to output folder: %@",
    "error.unknown": "Error",

    // Error Recovery
    "error.recovery.noVideoLoaded": "Open a video before exporting.",
    "error.recovery.noKeptSegments": "Keep at least one segment before exporting.",
    "error.recovery.trackLoadFailed": "The file may be corrupted or use an unsupported codec.",
    "error.recovery.exportFailed": "Try a different output location, or choose a lower resolution.",
    "error.recovery.recordingFailed": "Make sure you have enough disk space and the target is still available.",
    "error.recovery.screenRecordingPermissionDenied": "Go to System Settings → Privacy & Security → Screen Recording and enable ClipForge, then restart the app.",
    "error.recovery.microphonePermissionDenied": "Go to System Settings → Privacy & Security → Microphone and enable ClipForge, then restart the app.",
    "error.recovery.outputDirectoryNotWritable": "Choose a different output folder in Settings → Recording.",

    // Alerts
    "alert.ok": "OK",
    "alert.cancel": "Cancel",
    "alert.openSystemSettings": "Open System Settings",
    "alert.someVideosNotLoaded.title": "Some videos could not be loaded",
    "alert.someVideosNotLoaded.message": "%d file(s) were skipped.",
    "alert.someVideosNotLoaded.recovery": "The file may be corrupted or use an unsupported codec.",
    "alert.recordingSaved.title": "Recording Saved (partial)",
    "alert.exportComplete.title": "Export Complete",
    "alert.exporting": "Exporting… %.0f%%",
    "alert.exporting.message": "Video is being exported, please wait…",

    // Time Input
    "timeInput.goToTime": "Go to time",
    "timeInput.seekToTime": "Seek to the entered time",

    // Editing
    "editing.cutPointTooClose.title": "Cut point too close",
    "editing.cutPointTooClose.message": "There is already a cut point within %d ms.",

    // Recording
    "recording.saved.title": "Recording Saved",
    "recording.failed.title": "Recording Failed",
    "recording.failed.noFile": "No file was written.",
    "recording.recordButton": "Record",

    // Status Bar
    "statusBar.record": "Record",
    "statusBar.stop": "Stop",
    "statusBar.resume": "Resume",

    // Internal Errors
    "internalError.noDisplay": "No display",
    "internalError.noScreenForRegion": "No screen for region",
    "internalError.noDisplayFound": "No display found",
    "internalError.noMicrophone": "No microphone available",
    "internalError.cannotAddMicInput": "Cannot add microphone input",
    "internalError.cannotAddAudioOutput": "Cannot add audio output",
    "internalError.cannotCreateExportSession": "Could not create export session",
    "internalError.unknownError": "Unknown error",
]

// MARK: - Simplified Chinese

let zhHansStrings: [String: String] = [
    // Settings - Tabs
    "settings.tab.general": "通用",
    "settings.tab.recording": "录制",
    "settings.tab.editing": "编辑",

    // Settings - General
    "settings.general.language": "语言",
    "settings.general.quitAfterLastWindow": "关闭最后一个窗口后退出",
    "settings.general.dontHideWindow": "录制时不隐藏主窗口",
    "settings.general.countdown": "录制前倒计时",
    "settings.general.countdown.none": "无",
    "settings.general.countdown.3seconds": "3 秒",
    "settings.general.countdown.5seconds": "5 秒",

    // Settings - Recording
    "settings.recording.defaultMode": "默认模式",
    "settings.recording.mode": "录制模式",
    "settings.recording.mode.fullScreen": "全屏幕",
    "settings.recording.mode.window": "窗口",
    "settings.recording.mode.region": "区域",
    "settings.recording.buttonStyle": "按钮样式",
    "settings.recording.buttonStyle.modePicker": "先选模式再录制",
    "settings.recording.buttonStyle.directAction": "菜单项直接开始",
    "settings.recording.audio": "音频",
    "settings.recording.captureSystemAudio": "捕获系统音频",
    "settings.recording.captureMicrophone": "捕获麦克风",
    "settings.recording.microphoneGain": "麦克风增益",
    "settings.recording.video": "视频",
    "settings.recording.frameRate": "帧率",
    "settings.recording.codec": "编码",
    "settings.recording.format": "格式",
    "settings.recording.showCursor": "显示光标",
    "settings.recording.window": "窗口",
    "settings.recording.dontHideMainWindow": "录制时不隐藏主窗口",
    "settings.recording.outputFolder": "输出文件夹",
    "settings.recording.choose": "选择…",
    "settings.recording.reveal": "在 Finder 中显示",
    "settings.recording.30fps": "30 帧/秒",
    "settings.recording.60fps": "60 帧/秒",
    "settings.recording.h264": "H.264",
    "settings.recording.h265": "H.265 / HEVC",
    "settings.recording.mp4": "MP4",
    "settings.recording.mov": "MOV",

    // Settings - Editing
    "settings.editing.playback": "播放",
    "settings.editing.autoPlay": "打开视频时自动播放",
    "settings.editing.playbackEnd": "播放结束时",
    "settings.editing.playbackEnd.restart": "从头开始",
    "settings.editing.playbackEnd.next": "播放文件夹中的下一个",
    "settings.editing.playbackEnd.stop": "停止",
    "settings.editing.export": "导出",
    "settings.editing.resolution": "分辨率",
    "settings.editing.frameRate": "帧率",
    "settings.editing.format": "格式",

    // Export Options
    "export.resolution": "分辨率",
    "export.frameRate": "帧率",
    "export.format": "格式",
    "export.original": "原始",
    "export.1080p": "1080p",
    "export.720p": "720p",
    "export.480p": "480p",
    "export.30fps": "30 帧/秒",
    "export.60fps": "60 帧/秒",
    "export.mp4h264": "MP4 (H.264)",
    "export.mp4h265": "MP4 (H.265)",
    "export.mov": "MOV",

    // Menu - App
    "menu.app.about": "关于 %@",
    "menu.app.checkForUpdates": "检查更新…",
    "menu.app.settings": "设置…",
    "menu.app.hide": "隐藏 %@",
    "menu.app.hideOthers": "隐藏其他",
    "menu.app.showAll": "全部显示",
    "menu.app.quit": "退出 %@",

    // Menu - File
    "menu.file": "文件",
    "menu.file.newWindow": "新建窗口",
    "menu.file.open": "打开…",
    "menu.file.appendVideo": "追加视频…",
    "menu.file.export": "导出…",
    "menu.file.close": "关闭",

    // Menu - Edit
    "menu.edit": "编辑",
    "menu.edit.undo": "撤销",
    "menu.edit.redo": "重做",
    "menu.edit.cut": "剪切",
    "menu.edit.copy": "复制",
    "menu.edit.paste": "粘贴",
    "menu.edit.selectAll": "全选",

    // Menu - Playback
    "menu.playback": "播放",
    "menu.playback.playPause": "播放/暂停",
    "menu.playback.mute": "静音",
    "menu.playback.volumeUp": "音量增加",
    "menu.playback.volumeDown": "音量减少",
    "menu.playback.back1Frame": "后退 1 帧",
    "menu.playback.forward1Frame": "前进 1 帧",
    "menu.playback.back5Seconds": "后退 5 秒",
    "menu.playback.forward5Seconds": "前进 5 秒",

    // Menu - Record
    "menu.record": "录制",
    "menu.record.fullScreen": "全屏幕",
    "menu.record.window": "窗口",
    "menu.record.region": "区域",
    "menu.record.start": "开始录制",

    // Menu - Window
    "menu.window": "窗口",
    "menu.window.minimize": "最小化",
    "menu.window.zoom": "缩放",

    // Main UI
    "main.tooltip.open": "打开视频 (⌘O)",
    "main.tooltip.play": "播放 / 暂停 (空格)",
    "main.tooltip.scrub": "拖动以在时间轴上移动",
    "main.tooltip.setCutPoint": "在当前位置添加剪辑点",
    "main.tooltip.export": "导出 (⌘E)",
    "main.tooltip.record": "开始录制 (⌘R)",
    "main.tooltip.recordMode": "选择录制模式",
    "main.tooltip.volume": "音量",
    "main.tooltip.mute": "静音 / 取消静音 (⇧⌘M)",
    "main.tooltip.dontHide": "录制时保持主窗口可见",
    "main.tooltip.crop": "拖动以裁剪。按 Esc 重置。",
    "main.tooltip.timeline": "点击添加剪辑点。右键点击片段以保留/移除。双击剪辑点以删除。",
    "main.dontHide": "不隐藏",

    // Errors
    "error.noVideoLoaded": "未加载视频",
    "error.noKeptSegments": "没有可导出的内容",
    "error.trackLoadFailed": "无法加载视频轨道：%@",
    "error.exportFailed": "导出失败：%@",
    "error.exportCancelled": "导出已取消",
    "error.recordingFailed": "录制失败：%@",
    "error.screenRecordingPermissionDenied": "屏幕录制权限被拒绝",
    "error.microphonePermissionDenied": "麦克风权限被拒绝",
    "error.outputDirectoryNotWritable": "无法写入输出文件夹：%@",
    "error.unknown": "错误",

    // Error Recovery
    "error.recovery.noVideoLoaded": "请在导出前打开一个视频。",
    "error.recovery.noKeptSegments": "请在导出前至少保留一个片段。",
    "error.recovery.trackLoadFailed": "文件可能已损坏或使用了不支持的编码。",
    "error.recovery.exportFailed": "请尝试不同的输出位置，或选择较低的分辨率。",
    "error.recovery.recordingFailed": "请确保有足够的磁盘空间，且目标仍然可用。",
    "error.recovery.screenRecordingPermissionDenied": "前往系统设置 → 隐私与安全性 → 屏幕录制，启用 ClipForge，然后重启应用。",
    "error.recovery.microphonePermissionDenied": "前往系统设置 → 隐私与安全性 → 麦克风，启用 ClipForge，然后重启应用。",
    "error.recovery.outputDirectoryNotWritable": "在设置 → 录制中选择其他输出文件夹。",

    // Alerts
    "alert.ok": "确定",
    "alert.cancel": "取消",
    "alert.openSystemSettings": "打开系统设置",
    "alert.someVideosNotLoaded.title": "部分视频无法加载",
    "alert.someVideosNotLoaded.message": "%d 个文件被跳过。",
    "alert.someVideosNotLoaded.recovery": "文件可能已损坏或使用了不支持的编码。",
    "alert.recordingSaved.title": "录制已保存（部分）",
    "alert.exportComplete.title": "导出完成",
    "alert.exporting": "正在导出… %.0f%%",
    "alert.exporting.message": "视频导出中，请稍后…",

    // Time Input
    "timeInput.goToTime": "跳转到时间",
    "timeInput.seekToTime": "跳转到输入的时间",

    // Editing
    "editing.cutPointTooClose.title": "剪辑点太近",
    "editing.cutPointTooClose.message": "%d 毫秒内已有一个剪辑点。",

    // Recording
    "recording.saved.title": "录制已保存",
    "recording.failed.title": "录制失败",
    "recording.failed.noFile": "未生成文件。",
    "recording.recordButton": "录制",

    // Status Bar
    "statusBar.record": "录制",
    "statusBar.stop": "停止",
    "statusBar.resume": "继续",

    // Internal Errors
    "internalError.noDisplay": "无显示器",
    "internalError.noScreenForRegion": "没有屏幕对应此区域",
    "internalError.noDisplayFound": "未找到显示器",
    "internalError.noMicrophone": "无可用麦克风",
    "internalError.cannotAddMicInput": "无法添加麦克风输入",
    "internalError.cannotAddAudioOutput": "无法添加音频输出",
    "internalError.cannotCreateExportSession": "无法创建导出会话",
    "internalError.unknownError": "未知错误",
]

// MARK: - Traditional Chinese

let zhHantStrings: [String: String] = [
    // Settings - Tabs
    "settings.tab.general": "一般",
    "settings.tab.recording": "錄製",
    "settings.tab.editing": "編輯",

    // Settings - General
    "settings.general.language": "語言",
    "settings.general.quitAfterLastWindow": "關閉最後一個視窗後結束",
    "settings.general.dontHideWindow": "錄製時不隱藏主視窗",
    "settings.general.countdown": "錄製前倒數計時",
    "settings.general.countdown.none": "無",
    "settings.general.countdown.3seconds": "3 秒",
    "settings.general.countdown.5seconds": "5 秒",

    // Settings - Recording
    "settings.recording.defaultMode": "預設模式",
    "settings.recording.mode": "錄製模式",
    "settings.recording.mode.fullScreen": "全螢幕",
    "settings.recording.mode.window": "視窗",
    "settings.recording.mode.region": "區域",
    "settings.recording.buttonStyle": "按鈕樣式",
    "settings.recording.buttonStyle.modePicker": "先選模式再錄製",
    "settings.recording.buttonStyle.directAction": "選單項目直接開始",
    "settings.recording.audio": "音訊",
    "settings.recording.captureSystemAudio": "擷取系統音訊",
    "settings.recording.captureMicrophone": "擷取麥克風",
    "settings.recording.microphoneGain": "麥克風增益",
    "settings.recording.video": "視訊",
    "settings.recording.frameRate": "幀率",
    "settings.recording.codec": "編碼",
    "settings.recording.format": "格式",
    "settings.recording.showCursor": "顯示游標",
    "settings.recording.window": "視窗",
    "settings.recording.dontHideMainWindow": "錄製時不隱藏主視窗",
    "settings.recording.outputFolder": "輸出檔案夾",
    "settings.recording.choose": "選擇…",
    "settings.recording.reveal": "在 Finder 中顯示",
    "settings.recording.30fps": "30 幀/秒",
    "settings.recording.60fps": "60 幀/秒",
    "settings.recording.h264": "H.264",
    "settings.recording.h265": "H.265 / HEVC",
    "settings.recording.mp4": "MP4",
    "settings.recording.mov": "MOV",

    // Settings - Editing
    "settings.editing.playback": "播放",
    "settings.editing.autoPlay": "開啟視訊時自動播放",
    "settings.editing.playbackEnd": "播放結束時",
    "settings.editing.playbackEnd.restart": "從頭開始",
    "settings.editing.playbackEnd.next": "播放檔案夾中的下一個",
    "settings.editing.playbackEnd.stop": "停止",
    "settings.editing.export": "匯出",
    "settings.editing.resolution": "解析度",
    "settings.editing.frameRate": "幀率",
    "settings.editing.format": "格式",

    // Export Options
    "export.resolution": "解析度",
    "export.frameRate": "幀率",
    "export.format": "格式",
    "export.original": "原始",
    "export.1080p": "1080p",
    "export.720p": "720p",
    "export.480p": "480p",
    "export.30fps": "30 幀/秒",
    "export.60fps": "60 幀/秒",
    "export.mp4h264": "MP4 (H.264)",
    "export.mp4h265": "MP4 (H.265)",
    "export.mov": "MOV",

    // Menu - App
    "menu.app.about": "關於 %@",
    "menu.app.checkForUpdates": "檢查更新…",
    "menu.app.settings": "設定…",
    "menu.app.hide": "隱藏 %@",
    "menu.app.hideOthers": "隱藏其他",
    "menu.app.showAll": "全部顯示",
    "menu.app.quit": "結束 %@",

    // Menu - File
    "menu.file": "檔案",
    "menu.file.newWindow": "新增視窗",
    "menu.file.open": "打開…",
    "menu.file.appendVideo": "附加視訊…",
    "menu.file.export": "匯出…",
    "menu.file.close": "關閉",

    // Menu - Edit
    "menu.edit": "編輯",
    "menu.edit.undo": "還原",
    "menu.edit.redo": "重做",
    "menu.edit.cut": "剪下",
    "menu.edit.copy": "拷貝",
    "menu.edit.paste": "貼上",
    "menu.edit.selectAll": "全選",

    // Menu - Playback
    "menu.playback": "播放",
    "menu.playback.playPause": "播放/暫停",
    "menu.playback.mute": "靜音",
    "menu.playback.volumeUp": "音量提高",
    "menu.playback.volumeDown": "音量降低",
    "menu.playback.back1Frame": "後退 1 幀",
    "menu.playback.forward1Frame": "前進 1 幀",
    "menu.playback.back5Seconds": "後退 5 秒",
    "menu.playback.forward5Seconds": "前進 5 秒",

    // Menu - Record
    "menu.record": "錄製",
    "menu.record.fullScreen": "全螢幕",
    "menu.record.window": "視窗",
    "menu.record.region": "區域",
    "menu.record.start": "開始錄製",

    // Menu - Window
    "menu.window": "視窗",
    "menu.window.minimize": "縮到最小",
    "menu.window.zoom": "縮放",

    // Main UI
    "main.tooltip.open": "開啟視訊 (⌘O)",
    "main.tooltip.play": "播放 / 暫停 (空白鍵)",
    "main.tooltip.scrub": "拖曳以在時間軸上移動",
    "main.tooltip.setCutPoint": "在目前位置加入剪輯點",
    "main.tooltip.export": "匯出 (⌘E)",
    "main.tooltip.record": "開始錄製 (⌘R)",
    "main.tooltip.recordMode": "選擇錄製模式",
    "main.tooltip.volume": "音量",
    "main.tooltip.mute": "靜音 / 取消靜音 (⇧⌘M)",
    "main.tooltip.dontHide": "錄製時保持主視窗可見",
    "main.tooltip.crop": "拖曳以裁切。按 Esc 重置。",
    "main.tooltip.timeline": "點擊加入剪輯點。右鍵點擊片段以保留/移除。雙擊剪輯點以刪除。",
    "main.dontHide": "不隱藏",

    // Errors
    "error.noVideoLoaded": "未載入視訊",
    "error.noKeptSegments": "沒有可匯出的內容",
    "error.trackLoadFailed": "無法載入視訊軌道：%@",
    "error.exportFailed": "匯出失敗：%@",
    "error.exportCancelled": "匯出已取消",
    "error.recordingFailed": "錄製失敗：%@",
    "error.screenRecordingPermissionDenied": "螢幕錄製權限被拒絕",
    "error.microphonePermissionDenied": "麥克風權限被拒絕",
    "error.outputDirectoryNotWritable": "無法寫入輸出檔案夾：%@",
    "error.unknown": "錯誤",

    // Error Recovery
    "error.recovery.noVideoLoaded": "請在匯出前開啟一個視訊。",
    "error.recovery.noKeptSegments": "請在匯出前至少保留一個片段。",
    "error.recovery.trackLoadFailed": "檔案可能已損壞或使用了不支援的編碼。",
    "error.recovery.exportFailed": "請嘗試不同的輸出位置，或選擇較低的解析度。",
    "error.recovery.recordingFailed": "請確保有足夠的磁碟空間，且目標仍然可用。",
    "error.recovery.screenRecordingPermissionDenied": "前往系統設定 → 隱私權與安全性 → 螢幕錄製，啟用 ClipForge，然後重新啟動 App。",
    "error.recovery.microphonePermissionDenied": "前往系統設定 → 隱私權與安全性 → 麥克風，啟用 ClipForge，然後重新啟動 App。",
    "error.recovery.outputDirectoryNotWritable": "在設定 → 錄製中選擇其他輸出檔案夾。",

    // Alerts
    "alert.ok": "確定",
    "alert.cancel": "取消",
    "alert.openSystemSettings": "開啟系統設定",
    "alert.someVideosNotLoaded.title": "部分視訊無法載入",
    "alert.someVideosNotLoaded.message": "%d 個檔案被跳過。",
    "alert.someVideosNotLoaded.recovery": "檔案可能已損壞或使用了不支援的編碼。",
    "alert.recordingSaved.title": "錄製已儲存（部分）",
    "alert.exportComplete.title": "匯出完成",
    "alert.exporting": "正在匯出… %.0f%%",
    "alert.exporting.message": "視訊匯出中，請稍候…",

    // Time Input
    "timeInput.goToTime": "跳轉到時間",
    "timeInput.seekToTime": "跳轉到輸入的時間",

    // Editing
    "editing.cutPointTooClose.title": "剪輯點太近",
    "editing.cutPointTooClose.message": "%d 毫秒內已有一個剪輯點。",

    // Recording
    "recording.saved.title": "錄製已儲存",
    "recording.failed.title": "錄製失敗",
    "recording.failed.noFile": "未產生檔案。",
    "recording.recordButton": "錄製",

    // Status Bar
    "statusBar.record": "錄製",
    "statusBar.stop": "停止",
    "statusBar.resume": "繼續",

    // Internal Errors
    "internalError.noDisplay": "無顯示器",
    "internalError.noScreenForRegion": "沒有螢幕對應此區域",
    "internalError.noDisplayFound": "未找到顯示器",
    "internalError.noMicrophone": "無可用麥克風",
    "internalError.cannotAddMicInput": "無法加入麥克風輸入",
    "internalError.cannotAddAudioOutput": "無法加入音訊輸出",
    "internalError.cannotCreateExportSession": "無法建立匯出工作階段",
    "internalError.unknownError": "未知錯誤",
]