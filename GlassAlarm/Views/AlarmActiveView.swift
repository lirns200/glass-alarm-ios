import SwiftUI

struct AlarmActiveView: View {
    let alarm: Alarm
    let dismiss: () -> Void
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Динамический фон
            GlassBackground(theme: .dark)
                .opacity(animate ? 0.6 : 0.3)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Иконка и статус
                VStack(spacing: 16) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.bounce, options: .repeat(.infinite), value: animate)
                    
                    Text(alarm.title.isEmpty ? "БУДИЛЬНИК" : alarm.title.uppercased())
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .kerning(4)
                        .foregroundStyle(.white)
                }
                
                // Время
                Text(alarm.timeText)
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .scaleEffect(animate ? 1.05 : 1.0)
                
                Spacer()
                
                // Кнопки управления
                VStack(spacing: 20) {
                    Button {
                        // Логика подремать (в реальном приложении тут бы создавался новый пуш на +9 мин)
                        dismiss()
                    } label: {
                        Text("ПОДРЕМАТЬ")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.white.opacity(0.15), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("ВЫКЛЮЧИТЬ")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(Color.red.opacity(0.8), in: Capsule())
                            .shadow(color: .red.opacity(0.4), radius: 20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
