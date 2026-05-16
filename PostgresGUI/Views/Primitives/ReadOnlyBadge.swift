//
//  ReadOnlyBadge.swift
//  PostgresGUI
//

import SwiftUI

struct ReadOnlyBadge: View {
    var body: some View {
        Text("READ ONLY")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.red)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color.red.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .help("This connection is read-only. Data-changing statements are blocked.")
    }
}
