// PromptDisplayView.swift
// Vibe ID
//
// Created by Studio Carlos in 2025.
// Copyright (C) 2025 Studio Carlos
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import SwiftUI

struct PromptDisplayView: View {
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var recognitionViewModel: RecognitionViewModel
    @State private var currentPromptIndex = 0
    @State private var isAnimating = false
    @State private var scrollText = false
    @State private var textWidth: CGFloat = .zero
    @State private var scrollViewWidth: CGFloat = .zero
    
    // Timer for automatic prompt scrolling
    let autoChangeTimer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()
    
    var body: some View {
        promptContent
            .onReceive(autoChangeTimer) { _ in
                handleTimerTick()
            }
            .padding(.vertical)
    }
    
    // Main content
    private var promptContent: some View {
        VStack(spacing: 12) {
            if recognitionViewModel.llmState == .generating {
                LoadingPromptView()
            } else if let currentPrompt = llmManager.currentPrompts[safe: currentPromptIndex] {
                scrollingPromptView(for: currentPrompt)
                
                // Interactive progress indicator
                if llmManager.currentPrompts.count > 1 {
                    progressIndicator
                }
            }
        }
    }
    
    // Scrolling banner view
    private func scrollingPromptView(for prompt: LLMPrompt) -> some View {
        ZStack {
            // Banner background
            promptBackground
            
            // Scrolling content
            scrollingContent(for: prompt)
        }
        .frame(height: 50)
        .padding(.horizontal, 16)
    }
    
    // Styled banner background
    private var promptBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
    
    // Scrolling content with text
    private func scrollingContent(for prompt: LLMPrompt) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Prompt number with distinct effect
                Text("PROMPT \(currentPromptIndex + 1): ")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 4)
                
                // Prompt text
                Text(prompt.prompt)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .background(GeometryReader { geo in
                        Color.clear.onAppear {
                            textWidth = geo.size.width
                        }
                    })
                
                // Espace avant répétition
                Text("   •   ")
                    .foregroundColor(.cyan)
                    .fontWeight(.bold)
                
                // Répétition du texte pour effet continu
                Text(prompt.prompt)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .opacity(0.8)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .offset(x: scrollText ? -textWidth - 60 : 0)
            .animation(
                Animation.linear(duration: max(5, Double(prompt.prompt.count) / 10))
                    .repeatForever(autoreverses: false),
                value: scrollText
            )
        }
        .background(GeometryReader { geo in
            Color.clear.onAppear {
                scrollViewWidth = geo.size.width
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scrollText = true
                }
            }
        })
        .mask(
            // Masque avec dégradé aux bords pour un effet fondu
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.05),
                    .init(color: .white, location: 0.95),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // Indicateurs de progression (points)
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<llmManager.currentPrompts.count, id: \.self) { index in
                Circle()
                    .fill(currentPromptIndex == index ? Color.blue : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut, value: currentPromptIndex)
                    .onTapGesture {
                        changePrompt(to: index)
                    }
                    // Agrandir la zone tactile pour faciliter le tap
                    .contentShape(Rectangle().size(CGSize(width: 24, height: 24)))
                    .padding(9)
            }
        }
        .padding(.top, 8)
    }
    
    // Change le prompt et réinitialise l'animation
    private func changePrompt(to index: Int) {
        withAnimation {
            // Arrêter l'ancienne animation avant de changer
            scrollText = false
            
            // Changer de prompt
            currentPromptIndex = index
            
            // Réinitialiser l'animation après un court délai
            resetScrollAnimation()
        }
    }
    
    // Gère le tick du timer
    private func handleTimerTick() {
        withAnimation {
            // Passer au prompt suivant automatiquement seulement si on n'est pas en chargement
            if llmManager.currentPrompts.count > 1 && recognitionViewModel.llmState != .generating {
                // Passer au prompt suivant
                currentPromptIndex = (currentPromptIndex + 1) % llmManager.currentPrompts.count
                
                // Réinitialiser l'animation de défilement
                resetScrollAnimation()
            }
        }
    }
    
    // Réinitialise l'animation de défilement
    private func resetScrollAnimation() {
        scrollText = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            scrollText = true
        }
    }
}

// Vue pour afficher un paramètre
struct ParameterView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// Extension pour l'accès sécurisé aux tableaux
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Vue d'animation de chargement futuriste
struct LoadingPromptView: View {
    @State private var animationValue: CGFloat = 0
    @State private var pulseOpacity: Double = 0.7
    
    var body: some View {
        ZStack {
            // Fond du bandeau
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    // Effet de pulsation
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(pulseOpacity), Color.purple.opacity(pulseOpacity)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .blur(radius: 3)
                )
            
            // Contenu
            HStack(spacing: 16) {
                // Icône de chargement simplifiée
                Circle()
                    .stroke(Color.cyan.opacity(0.8), lineWidth: 1)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .offset(x: 8 * cos(Double(animationValue)), y: 8 * sin(Double(animationValue)))
                    )
                    .frame(width: 30, height: 30)
                
                // Texte
                Text("AI PROMPT GENERATION")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .kerning(0.5)
                
                // Indicateur simple
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 6, height: 6)
                    .opacity(0.2 + 0.8 * sin(Double(animationValue)))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .frame(height: 50)
        .padding(.horizontal, 16)
        .onAppear {
            // Démarrer l'animation
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                animationValue = 2 * .pi
            }
            
            // Animation de pulsation
            withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.3
            }
        }
    }
} 