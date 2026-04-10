import Foundation

class MainFlow {
    static let shared = MainFlow()
    
    private let auth = AuthService.shared
    private let study = StudyService.shared
    private let resource = ResourceService.shared
    private let flashcard = FlashcardService.shared
    private let attempt = AttemptService.shared
    
    func runFullFlow() async {
        do {
            print("🚀 Iniciando flujo principal...")
            
            // 1. Autenticación
            print("🔐 Paso 1: Autenticación")
            let loginDto = LoginDto(email: "carlos@mail.com", password: "password123")
            try await auth.login(dto: loginDto)
            print("✅ Login exitoso")
            
            // 2. Crear un estudio
            print("📚 Paso 2: Crear Estudio")
            let newStudy = try await study.create(dto: CreateStudyDto(
                title: "Biología Celular",
                description: "Apuntes del parcial 2 sobre fotosíntesis y organelos"
            ))
            print("✅ Estudio creado: \(newStudy.title) (ID: \(newStudy.id))")
            
            // 3. Agregar un recurso
            print("📄 Paso 3: Agregar Recurso")
            let newResource = try await resource.create(studyId: newStudy.id, dto: CreateResourceDto(
                title: "Clase 3 - Fotosíntesis",
                content: "La fotosíntesis es el proceso por el cual las plantas convierten luz en energía química...",
                sourceName: "clase3.pdf"
            ))
            print("✅ Recurso agregado: \(newResource.title)")
            
            // 4. Generar y Guardar Flashcards (Simulando Foundation Models)
            print("🎴 Paso 4: Generar y Guardar Flashcards")
            let flashcardsToCreate = [
                CreateFlashcardDto(
                    question: "¿Dónde ocurre la fotosíntesis?",
                    answer: "En los cloroplastos",
                    conceptTags: ["fotosíntesis", "cloroplasto"],
                    resourceId: newResource.id,
                    type: .open,
                    options: nil
                ),
                CreateFlashcardDto(
                    question: "¿Qué gas se libera en la fotosíntesis?",
                    answer: "Oxígeno",
                    conceptTags: ["fotosíntesis", "gases"],
                    resourceId: newResource.id,
                    type: .multipleChoice,
                    options: FlashcardOptions(correct: "Oxígeno", distractors: ["Dióxido de carbono", "Nitrógeno", "Hidrógeno"])
                )
            ]
            let savedFlashcards = try await flashcard.createBatch(studyId: newStudy.id, dtos: flashcardsToCreate)
            print("✅ \(savedFlashcards.count) flashcards guardadas")
            
            // 5. Sesión de Práctica
            print("🎯 Paso 5: Sesión de Práctica")
            
            // 5.1 Obtener Gaps y Cola de Repaso
            let gaps = try await attempt.getGaps(studyId: newStudy.id)
            let queue = try await flashcard.getReviewQueue(studyId: newStudy.id)
            print("✅ Gaps obtenidos: \(gaps.gaps.count). Cards en cola: \(queue.count)")
            
            // 5.2 Simular respuesta a la primera flashcard
            if let firstCard = queue.first {
                print("📝 Respondiendo a: \(firstCard.question)")
                
                // Simulación de evaluación por Foundation Models
                let attemptDto = CreateAttemptDto(
                    userAnswer: "En los cloroplastos",
                    isCorrect: true,
                    errorType: nil,
                    missingConcepts: [],
                    incorrectConcepts: [],
                    feedback: "¡Correcto!",
                    confidenceScore: 0.95
                )
                
                let savedAttempt = try await attempt.create(flashcardId: firstCard.id, dto: attemptDto)
                print("✅ Intento guardado. Accuracy actual del estudio: \(try await attempt.listForStudy(studyId: newStudy.id).accuracy)")
            }
            
            print("🏁 Flujo completado con éxito")
            
        } catch {
            print("❌ Error en el flujo: \(error)")
        }
    }
}
