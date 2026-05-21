import SwiftUI

struct SplashScreenView: View {

    // MARK: – Animation States
    @State private var logoScale:      CGFloat = 0.05   // startet winzig (Tiefe)
    @State private var logoOpacity:    Double  = 0.0
    @State private var logoRotationY:  Double  = -90.0  // startet von -90° (links hinten)
    @State private var logoRotationX:  Double  = 20.0   // leicht nach hinten gekippt
    @State private var nameOpacity:    Double  = 0.0
    @State private var nameOffset:     CGFloat = 30
    @State private var taglineOpacity: Double  = 0.0
    @State private var taglineOffset:  CGFloat = 20
    @State private var bgOpacity:      Double  = 1.0
    @State private var shimmerOffset:  CGFloat = -200
    @State private var glowRadius:     CGFloat = 0
    @State private var glowOpacity:    Double  = 0.0
    @State private var wave1Scale:     CGFloat = 1.0
    @State private var wave1Opacity:   Double  = 0.0
    @State private var wave2Scale:     CGFloat = 1.0
    @State private var wave2Opacity:   Double  = 0.0
    @State private var wave3Scale:     CGFloat = 1.0
    @State private var wave3Opacity:   Double  = 0.0

    var onFinished: () -> Void

    // MARK: – Body
    var body: some View {
        ZStack {

            // ── Hintergrund: Dunkelblau → Cyan-Akzent ────────────────
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.07, blue: 0.16),
                    Color(red: 0.05, green: 0.13, blue: 0.26),
                    Color(red: 0.03, green: 0.19, blue: 0.30)
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .opacity(bgOpacity)

            // ── Subtiler Cyan-Schimmer oben rechts ───────────────────
            RadialGradient(
                colors: [
                    Color(red: 0.10, green: 0.70, blue: 0.85).opacity(0.10),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()
            .opacity(bgOpacity)

            // ── Subtile Hintergrund-Partikel ──────────────────────────
            ForEach(0..<12, id: \.self) { i in
                Circle()
                    .fill(
                        i % 3 == 0
                        ? Color(red: 0.10, green: 0.70, blue: 0.85).opacity(0.04 + Double(i) * 0.003)
                        : Color.white.opacity(0.02 + Double(i) * 0.003)
                    )
                    .frame(width: CGFloat(15 + i * 14), height: CGFloat(15 + i * 14))
                    .offset(
                        x: CGFloat([-140,-80,60,110,-30,90,-100,40,-60,120,-90,70][i % 12]),
                        y: CGFloat([-280,-180,-120,60,160,-60,220,-200,280,100,-240,320][i % 12])
                    )
                    .opacity(bgOpacity)
            }

            // ── Hauptinhalt ───────────────────────────────────────────
            VStack(spacing: 0) {

                Spacer()

                // Logo-Container
                ZStack {

                    // ── Wellen-Pulse: Cyan ─────────────────────────────
                    Circle()
                        .stroke(Color(red: 0.10, green: 0.72, blue: 0.88).opacity(0.55), lineWidth: 2.5)
                        .frame(width: 120, height: 120)
                        .scaleEffect(wave1Scale)
                        .opacity(wave1Opacity)

                    Circle()
                        .stroke(Color(red: 0.10, green: 0.72, blue: 0.88).opacity(0.18), lineWidth: 1.0)
                        .frame(width: 120, height: 120)
                        .scaleEffect(wave2Scale)
                        .opacity(wave2Opacity)

                    Circle()
                        .stroke(Color(red: 0.10, green: 0.72, blue: 0.88).opacity(0.10), lineWidth: 0.5)
                        .frame(width: 120, height: 120)
                        .scaleEffect(wave3Scale)
                        .opacity(wave3Opacity)

                    // ── Glow-Halo: Cyan ────────────────────────────────
                    Circle()
                        .fill(Color(red: 0.08, green: 0.60, blue: 0.80).opacity(0.20))
                        .frame(width: 160, height: 160)
                        .blur(radius: glowRadius)
                        .opacity(glowOpacity)

                    // ── Icon-Hintergrund: Dunkelblau → Cyan ───────────
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.45, blue: 0.72),  // Mittelblau
                                    Color(red: 0.03, green: 0.25, blue: 0.50),  // Dunkelblau
                                    Color(red: 0.02, green: 0.18, blue: 0.38)   // fast Nacht
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .shadow(color: Color(red: 0.10, green: 0.65, blue: 0.82).opacity(0.35),
                                radius: 28, x: 0, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.20, green: 0.75, blue: 0.90).opacity(0.45),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.0
                                )
                        )

                    // ── App Icon ───────────────────────────────────────
                    Image(systemName: "car.fill")
                        .font(.system(size: 70, weight: .regular))
                        .foregroundStyle(.white)

                    // ── Shimmer ────────────────────────────────────────
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.28), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 130, height: 130)
                        .offset(x: shimmerOffset)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .frame(width: 130)
                }
                // ── 3D: Tiefenflug + Y-Rotation + X-Tilt kombiniert ───
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .rotation3DEffect(
                    .degrees(logoRotationY),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    perspective: 0.5
                )
                .rotation3DEffect(
                    .degrees(logoRotationX),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .center,
                    perspective: 0.4
                )

                // ── App-Name: Weiss mit leichtem Cyan-Schimmer ────────
                Text("Fahrtkosten")
                    .font(.system(size: 42, weight: .regular, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.75, green: 0.93, blue: 1.00)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 28)
                    .opacity(nameOpacity)
                    .offset(y: nameOffset)

                // ── Tagline: Cyan-Grau ─────────────────────────────────
                Text("Dienstreisen smart abrechnen")
                    .font(.system(size: 19, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.78, blue: 0.88).opacity(0.75))
                    .padding(.top, 8)
                    .opacity(taglineOpacity)
                    .offset(y: taglineOffset)

                Spacer()

                // ── Ladeindikator ──────────────────────────────────────
                VStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(red: 0.20, green: 0.75, blue: 0.90).opacity(0.6))
                        .scaleEffect(0.8)
                    Text("Wird geladen …")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(red: 0.40, green: 0.65, blue: 0.78).opacity(0.55))
                }
                .opacity(taglineOpacity)
                .padding(.bottom, 48)
            }
        }
        .onAppear { startAnimation() }
    }

    // MARK: – Animation Sequence
    private func startAnimation() {

        // Phase 1: Opacity sofort sichtbar machen
        withAnimation(.easeIn(duration: 0.15).delay(0.1)) {
            logoOpacity = 1.0
        }

        // Phase 1: Tiefenflug – scale 0.05 → 1.0 mit Federwirkung
        withAnimation(.spring(response: 0.75, dampingFraction: 0.60).delay(0.1)) {
            logoScale = 1.0
        }

        // Phase 1: Y-Rotation – -90° → 0° (dreht sich aus der Tiefe rein)
        withAnimation(.spring(response: 0.80, dampingFraction: 0.68).delay(0.12)) {
            logoRotationY = 0
        }

        // Phase 1: X-Tilt – 20° → 0° (richtet sich auf, minimal später)
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72).delay(0.18)) {
            logoRotationX = 0
        }

        // Phase 2: Glow erscheint nach Landung
        withAnimation(.easeOut(duration: 0.5).delay(0.75)) {
            glowRadius  = 22
            glowOpacity = 1.0
        }

        // Phase 3: Wellen-Pulse nach Landung
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.90) {
            pulseWave(scale: $wave1Scale, opacity: $wave1Opacity, delay: 0.00)
            pulseWave(scale: $wave2Scale, opacity: $wave2Opacity, delay: 0.22)
            pulseWave(scale: $wave3Scale, opacity: $wave3Opacity, delay: 0.44)
        }

        // Phase 4: Shimmer über das Logo
        withAnimation(.easeInOut(duration: 0.75).delay(0.95)) {
            shimmerOffset = 200
        }

        // Phase 5: App-Name gleitet herein
        withAnimation(.easeOut(duration: 0.45).delay(1.05)) {
            nameOpacity = 1.0
            nameOffset  = 0
        }

        // Phase 6: Tagline + Ladeindikator
        withAnimation(.easeOut(duration: 0.35).delay(1.30)) {
            taglineOpacity = 1.0
            taglineOffset  = 0
        }

        // Phase 7: Ausblenden & App öffnen
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.40)) {
                bgOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                onFinished()
            }
        }
    }

    // Einzelne Welle ausstrahlen
    private func pulseWave(scale: Binding<CGFloat>, opacity: Binding<Double>, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            scale.wrappedValue   = 1.0
            opacity.wrappedValue = 1.0
            withAnimation(.easeOut(duration: 0.90)) {
                scale.wrappedValue   = 4.5
                opacity.wrappedValue = 0.0
            }
        }
    }
}

// MARK: – Preview
#Preview {
    SplashScreenView(onFinished: {})
}
