import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject var appState: AppState // Necesitaremos un estado global
    
    var body: some View {
        ZStack {
            // Fondo con gradiente sutil
            LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo o Icono
                VStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .shadow(radius: 5)
                    
                    Text("Aero")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    
                    Text("Tu estudio, potenciado")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Formulario
                VStack(spacing: 20) {
                    if viewModel.isRegistering {
                        CustomTextField(icon: "person", placeholder: "Nombre de usuario", text: $viewModel.username)
                    }
                    
                    CustomTextField(icon: "envelope", placeholder: "Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    CustomSecureField(icon: "lock", placeholder: "Contraseña", text: $viewModel.password)
                }
                .padding(.horizontal)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Botón Principal
                Button {
                    Task {
                        await viewModel.authenticate()
                        if viewModel.isAuthenticated {
                            appState.isAuthenticated = true
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(viewModel.isRegistering ? "Crear cuenta" : "Iniciar sesión")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 3)
                }
                .disabled(viewModel.isLoading)
                .padding(.horizontal)
                
                // Toggle Login/Register
                Button {
                    withAnimation {
                        viewModel.isRegistering.toggle()
                    }
                } label: {
                    Text(viewModel.isRegistering ? "¿Ya tienes cuenta? Inicia sesión" : "¿No tienes cuenta? Regístrate")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// Componentes Reutilizables de UI
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 30)
            TextField(placeholder, text: $text)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
}

#Preview("Auth") {
    AuthView()
        .environmentObject(AppState())
}

#Preview("Campo texto") {
    CustomTextField(icon: "envelope", placeholder: "Email", text: .constant("demo@mail.com"))
        .padding()
}

#Preview("Campo seguro") {
    CustomSecureField(icon: "lock", placeholder: "Contraseña", text: .constant(""))
        .padding()
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 30)
            SecureField(placeholder, text: $text)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
