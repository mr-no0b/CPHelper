import SwiftUI

struct InlineMessageCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)

            Text(detail)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }
}

struct ChartLegendRow: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.text)

                Text(detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            }

            Spacer()
        }
    }
}

struct PracticeActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isBusy = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                        .tint(tint)
                } else {
                    Image(systemName: systemImage)
                }

                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled || isBusy)
        .opacity((disabled || isBusy) ? 0.65 : 1)
    }
}

struct CapsuleChoiceRow<Value: Hashable>: View {
    let values: [Value]
    let title: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Button {
                        selection = value
                    } label: {
                        Text(title(value))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(selection == value ? .white : AppTheme.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        selection == value
                                            ? AnyShapeStyle(AppTheme.heroGradient)
                                            : AnyShapeStyle(Color.white.opacity(0.92))
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CodeforcesProblemCard: View {
    let problem: CodeforcesProblem
    let subtitle: String
    let isInTodo: Bool
    let todoButtonTitle: String
    let todoButtonTint: Color
    var todoSystemImage: String? = nil
    var isTodoActionDisabled = false
    var isEditorialLoading = false
    var footerNote: String?
    let onOpenProblem: () -> Void
    let onTodoAction: () -> Void
    let onAskChatbot: () -> Void
    let onOpenEditorial: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onOpenProblem) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(problem.name)
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(AppTheme.text)
                                .multilineTextAlignment(.leading)

                            Text("\(problem.displayID) | \(subtitle)")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.mutedText)
                        }

                        Spacer()

                        if let rating = problem.rating {
                            InfoBadge(title: "\(rating)", tint: AppTheme.accent)
                        }
                    }

                    if !problem.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(problem.tags.prefix(5), id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .foregroundStyle(AppTheme.accentSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(AppTheme.accentSecondary.opacity(0.12))
                                        )
                                }
                            }
                        }
                    }

                    if let footerNote {
                        Text(footerNote)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    PracticeActionButton(
                        title: todoButtonTitle,
                        systemImage: todoSystemImage ?? (isInTodo ? "checkmark.circle.fill" : "plus.circle.fill"),
                        tint: todoButtonTint,
                        disabled: isTodoActionDisabled,
                        action: onTodoAction
                    )

                    PracticeActionButton(
                        title: "Editorial",
                        systemImage: "doc.text.magnifyingglass",
                        tint: AppTheme.warm,
                        isBusy: isEditorialLoading,
                        action: onOpenEditorial
                    )
                }

                PracticeActionButton(
                    title: "Ask Chatbot",
                    systemImage: "message.fill",
                    tint: AppTheme.accentSecondary,
                    action: onAskChatbot
                )
            }
        }
        .appCard()
    }
}
