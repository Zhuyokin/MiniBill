import SwiftUI

struct EntryShareCard: View {
    let payload: EntrySharePayload
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 52) {
            HStack {
                AppBrandIcon(size: 64, cornerRadius: 14)
                Text("MiniBill").font(.system(size: 32, weight: .bold)).foregroundStyle(.black)
                Spacer()
                Text(payload.kind == .income ? "Income" : "Expense")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(payload.kind == .income ? AppTheme.brandDark : .black)
                    .padding(.horizontal, 22).frame(height: 48)
                    .background(Color(white: 0.95), in: Capsule())
            }
            Spacer()
            VStack(alignment: .leading, spacing: 24) {
                Text(payload.projectName)
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(3)
                    .minimumScaleFactor(0.65)
                Text("\(payload.kind == .income ? "+" : "−")\(AppFormat.money(payload.amountCents, locale: locale))")
                    .font(.system(size: 82, weight: .bold, design: .rounded))
                    .foregroundStyle(payload.kind == .income ? AppTheme.brandDark : .black)
                    .minimumScaleFactor(0.5).lineLimit(1)
                Text(AppFormat.longDateTime(payload.occurredAt, locale: locale))
                    .font(.system(size: 26, weight: .medium)).foregroundStyle(.gray)
            }
            Spacer()
            Text("Made locally with MiniBill")
                .font(.system(size: 20, weight: .medium)).foregroundStyle(.gray)
        }
        .padding(72)
        .frame(width: 900, height: 1200, alignment: .topLeading)
        .background(Color.white)
    }
}
