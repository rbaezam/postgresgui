//
//  PostgresGUIApp.swift
//  PostgresGUI
//
//  Created by ghazi on 11/28/25.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct PostgresGUIApp: App {
    init() {
        #if DEBUG
        DebugLog.configureLogging()
        #endif
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ConnectionProfile.self,
            SavedQuery.self,
            QueryFolder.self,
            TabState.self,
            QueryHistoryEntry.self,
        ])

        // App-specific store path so we don't collide with the global
        // `~/Library/Application Support/default.store` that other
        // unsandboxed SwiftData apps may also use (and that the
        // migration-fallback below blindly deletes). In a sandboxed
        // Release build this resolves inside the app container; in
        // unsigned Debug builds it stays under the user's global
        // Application Support but scoped to a Postgresso subdirectory.
        let appSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDirectory = appSupportURL.appendingPathComponent(
            "Postgresso",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true
        )
        let storeURL = appDirectory.appendingPathComponent("default.store")

        // One-shot migration: if a previous build wrote to the un-scoped
        // global `~/Library/Application Support/default.store` path
        // (which was vulnerable to wipes from collisions with other
        // unsandboxed SwiftData apps), copy those files into our new
        // scoped directory once. If schema doesn't match, the catch
        // block below will recover by wiping our scoped store; the
        // global file is left alone so the user can delete it manually.
        let legacyStoreURL = appSupportURL.appendingPathComponent("default.store")
        if FileManager.default.fileExists(atPath: legacyStoreURL.path),
           !FileManager.default.fileExists(atPath: storeURL.path) {
            let legacyFiles = [
                "default.store",
                "default.store-wal",
                "default.store-shm",
            ]
            for name in legacyFiles {
                let src = appSupportURL.appendingPathComponent(name)
                let dst = appDirectory.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: src.path) {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
            Swift.print("ℹ️ Migrated SwiftData store from \(legacyStoreURL.path) to \(storeURL.path)")
        }

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, delete only OUR store files and try again.
            // Critical errors should remain visible in Release builds
            Swift.print("⚠️ Failed to create ModelContainer: \(error)")
            Swift.print("⚠️ Attempting to delete old database and create fresh...")

            do {
                let storeFiles = [
                    storeURL,
                    storeURL.appendingPathExtension("wal"),
                    storeURL.appendingPathExtension("shm")
                ]

                for file in storeFiles {
                    if FileManager.default.fileExists(atPath: file.path) {
                        try FileManager.default.removeItem(at: file)
                        DebugLog.print("✅ Removed: \(file.lastPathComponent)")
                    }
                }

                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after cleanup: \(error)")
            }
        }
    }()

    var body: some Scene {
        Window("PostgresGUI", id: "main") {
            RootView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(action: openNewTab) {
                    Text("New Tab")
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button(action: closeCurrentTab) {
                    Text("Close Tab")
                }
                .keyboardShortcut("w", modifiers: [.command])
            }

            CommandGroup(after: .appInfo) {
                Button(action: {
                    if let url = URL(string: "https://postgresgui.com/support") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("Help and Support...", systemImage: "questionmark.circle")
                }

                Button(action: {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
                }) {
                    Label("Keyboard Shortcuts...", systemImage: "keyboard")
                }

                Button(action: {
                    NotificationCenter.default.post(name: .openCommandPalette, object: nil)
                }) {
                    Label("Command Palette…", systemImage: "command.square")
                }
                .keyboardShortcut("k", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button(action: {
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                }) {
                    Text("PostgresGUI Help")
                }
            }
        }

        Settings {
            SettingsView()
        }
    }

    // Menu commands can't access TabManager directly, so we use notifications.
    // RootView observes these and calls tabManager methods.
    private func openNewTab() {
        NotificationCenter.default.post(name: .createNewTab, object: nil)
    }
    private func closeCurrentTab() {
        NotificationCenter.default.post(name: .closeCurrentTab, object: nil)
    }
}

extension Notification.Name {
    static let createNewTab = Notification.Name("createNewTab")
    static let closeCurrentTab = Notification.Name("closeCurrentTab")
    static let showKeyboardShortcuts = Notification.Name("showKeyboardShortcuts")
    static let showHelp = Notification.Name("showHelp")
    static let openCommandPalette = Notification.Name("openCommandPalette")
    static let loadSavedQuery = Notification.Name("loadSavedQuery")
}
