# Funcionalidades de Accesibilidad — TDAH · TEA · Dislexia
> Para implementar en SwiftUI + SwiftData + Foundation Models  
> Todas las preferencias se leen desde @AppStorage("accessibilityNeeds")

---

## Tabla de contenidos

1. [Sistema de preferencias](#sistema-de-preferencias)
2. [TDAH](#tdah)
3. [TEA — Autismo](#tea--autismo)
4. [Dislexia](#dislexia)
5. [Prompts de Foundation Models por perfil](#prompts-de-foundation-models-por-perfil)
6. [Prompt para Cursor](#prompt-para-cursor)

---

## Sistema de preferencias

Todas las adaptaciones se activan leyendo `@AppStorage("accessibilityNeeds")` que contiene un string separado por comas con los valores seleccionados en onboarding o settings.

```swift
@AppStorage("accessibilityNeeds") var accessibilityNeeds: String = ""

// Helper para verificar si tiene una necesidad específica
var hasADHD: Bool { accessibilityNeeds.contains("adhd") }
var hasAutism: Bool { accessibilityNeeds.contains("autism") }
var hasDyslexia: Bool { accessibilityNeeds.contains("dyslexia") }
var hasLowVision: Bool { accessibilityNeeds.contains("low_vision") }
```

Las adaptaciones se aplican automáticamente en toda la app según estos valores. El usuario puede cambiarlos en cualquier momento desde Settings.

---

## TDAH

### 1. Microlearning — Bloques de 3 flashcards

En lugar de sesiones ilimitadas, las flashcards se agrupan en bloques de exactamente 3. Al completar un bloque aparece una pantalla de pausa con dos opciones: continuar o terminar la sesión. El usuario siempre decide activamente si sigue — nunca se avanza automáticamente.

**SwiftData:** guardar `sessionBlockSize: Int = 3` en `UserProfile`. Para usuarios sin TDAH el default es 10.

**UI de pausa entre bloques:**
```
┌─────────────────────────────┐
│                             │
│   🔥 Bloque completado      │
│                             │
│   Llevas 3 flashcards       │
│   Racha actual: 2 correctas │
│                             │
│   [ Continuar → ]           │
│   [ Terminar por hoy ]      │
│                             │
└─────────────────────────────┘
```

---

### 2. Modo "Una sola cosa" — Focus Mode

Pantalla completamente vacía excepto la pregunta actual. Sin barra de navegación, sin contador de progreso, sin menú, sin elementos decorativos. Solo la pregunta, el campo de respuesta y el botón de enviar.

**Activación:** automático si `hasADHD == true`. También disponible como toggle manual en Settings para cualquier usuario.

```swift
@AppStorage("focusMode") var focusMode: Bool = false

// En la vista de flashcard:
if !focusMode {
    ProgressBar()
    NavigationBar()
    StudyTitle()
}
```

**UI en Focus Mode:**
```
┌─────────────────────────────┐
│                             │
│                             │
│  ¿Cuál es la función        │
│  del cloroplasto?           │
│                             │
│                             │
│  ┌─────────────────────┐    │
│  │ Tu respuesta...     │    │
│  └─────────────────────┘    │
│                             │
│        [ Enviar ]           │
│                             │
└─────────────────────────────┘
```

---

### 3. Racha visible con recompensa funcional

Mostrar racha de respuestas correctas consecutivas. Al llegar a 5 seguidas, ofrecer activamente el "Modo Difícil" — preguntas más complejas generadas por Foundation Models. La recompensa no es decorativa, tiene consecuencia real en la sesión.

**UI de racha:**
```
🔥 4 seguidas
```

**UI al llegar a 5:**
```
┌─────────────────────────────┐
│                             │
│   🔥 ¡5 seguidas!           │
│                             │
│   ¿Quieres intentar         │
│   el modo difícil?          │
│                             │
│   [ Modo difícil → ]        │
│   [ Seguir igual ]          │
│                             │
└─────────────────────────────┘
```

**SwiftData:** guardar `currentStreak: Int` y `bestStreak: Int` en `UserProfile`.

---

### 4. Timer de inversión — no de presión

No un countdown. Una barra que crece mostrando el tiempo invertido en la sesión actual, no el tiempo que falta. El usuario ve cuánto lleva sin sentir que se acaba el tiempo.

**UI:**
```
Sesión actual  ████████░░░░  12 min
```

Implementar con `TimelineView` en SwiftUI. La barra crece de izquierda a derecha. Nunca muestra "tiempo restante". Se resetea al iniciar cada sesión.

---

### 5. Feedback de un solo punto

Foundation Models recibe instrucción de reportar solo el error más importante si hay varios. Nunca listar múltiples correcciones en un mismo feedback. Si hay más errores secundarios, el sistema los guarda para la siguiente oportunidad en que aparezca esa flashcard.

**Lógica:**
```swift
// Al mostrar feedback para perfil TDAH:
// - Mostrar solo la primera corrección
// - Guardar correcciones adicionales en SwiftData
// - Mostrarlas la próxima vez que aparezca esa flashcard

struct FeedbackView: View {
    let feedback: FlashcardFeedback
    var hasADHD: Bool

    var displayedFeedback: String {
        hasADHD ? feedback.primaryCorrection : feedback.fullFeedback
    }
}
```

---

### 6. Modo Historia — alternativo a flashcards

Foundation Models genera una historia corta (5-8 oraciones) donde los conceptos del estudio son personajes o eventos. El usuario lee o escucha la historia y luego responde preguntas sobre ella. Mantiene la atención mejor que el formato pregunta-respuesta directo.

**UI — selector de modo al iniciar sesión:**
```
┌─────────────────────────────┐
│  ¿Cómo quieres practicar?   │
│                             │
│  ○ Flashcards               │
│    Preguntas directas       │
│                             │
│  ○ Modo Historia  ⭐ TDAH   │
│    Aprende con una          │
│    historia corta           │
│                             │
│  ○ Examen simulado          │
│    Preguntas abiertas       │
└─────────────────────────────┘
```

El badge "⭐ TDAH" solo aparece si `hasADHD == true` para que el usuario entienda por qué se le recomienda ese modo.

---

## TEA — Autismo

### 1. Modo Rutina

El usuario define su rutina de estudio: qué estudios practicar, en qué orden y cuántas flashcards por estudio. La app replica esa rutina exactamente cada vez que el usuario entra. Sin variaciones, sin sugerencias inesperadas, sin cambios de layout.

**SwiftData — StudyRoutine model:**
```swift
@Model
class StudyRoutine {
    var studyId: UUID
    var order: Int
    var flashcardsPerSession: Int
    var isActive: Bool
}
```

**UI de configuración de rutina:**
```
┌─────────────────────────────┐
│  Mi rutina de estudio       │
│                             │
│  1. Biología celular   10 ↕ │
│  2. Historia de México  5 ↕ │
│  3. Cálculo diferencial 8 ↕ │
│                             │
│  [ + Agregar estudio ]      │
│                             │
│  Al abrir la app, tu        │
│  rutina inicia sola         │
└─────────────────────────────┘
```

Los números son editables con stepper. El orden es arrastrable con `.onMove`. Al abrir la app con `hasAutism == true`, si hay rutina configurada, inicia directamente sin pasar por el home.

---

### 2. Feedback con template fijo

El feedback siempre tiene exactamente el mismo formato, sin variación. Nunca cambia la estructura aunque cambie el contenido. Implementar como template en el prompt de Foundation Models.

**Formato fijo de feedback:**
```
Estado: Correcto ✓  /  Incorrecto ✗  /  Parcial ◐

Mencionaste: [concepto1], [concepto2]
Faltó: [concepto3]
Incorrecto: [concepto4]

Próxima vez recuerda: [una sola oración concreta]
```

Este template nunca cambia para usuarios con `hasAutism == true`. La predictibilidad del formato reduce la carga cognitiva de interpretar el feedback.

---

### 3. Intereses especiales como ancla

En Settings, el usuario puede agregar sus temas de interés. Foundation Models usa esos intereses para generar analogías cuando detecta que el usuario falló un concepto.

**SwiftData:**
```swift
// Agregar a UserProfile:
var specialInterests: [String] = []  // ej: ["trenes", "astronomía", "minecraft"]
```

**UI en Settings:**
```
┌─────────────────────────────┐
│  Mis temas favoritos        │
│                             │
│  🚂 Trenes          [ × ]   │
│  🌌 Astronomía      [ × ]   │
│                             │
│  [ + Agregar tema ]         │
│                             │
│  Los usamos para explicar   │
│  conceptos difíciles        │
└─────────────────────────────┘
```

**Prompt cuando hay laguna detectada:**
```
El usuario tiene dificultad con el concepto: [concepto]
Sus temas de interés son: [intereses]
Genera una analogía que explique [concepto] usando [interés más relevante].
La analogía debe ser literal y concreta, sin metáforas abstractas.
```

---

### 4. Sin presión temporal — modo silencioso

Para usuarios con `hasAutism == true`:
- Nunca mostrar tiempo transcurrido durante la sesión
- Nunca mostrar mensajes de "¿sigues ahí?" después de pausa larga
- Nunca mostrar notificaciones de racha perdida
- El usuario puede pausar indefinidamente sin que la app reaccione

```swift
// Desactivar todos los timers y mensajes de inactividad:
if !hasAutism {
    InactivityTimer()
    StreakLostMessage()
    SessionTimeDisplay()
}
```

---

### 5. Modo sin color semántico

Correcto/incorrecto se comunica solo con texto y forma geométrica, sin rojo/verde. Para usuarios con procesamiento atípico del color como señal emocional.

**Sin modo sin color:**
```
✅ Verde — Correcto
❌ Rojo — Incorrecto
```

**Con modo sin color:**
```
■ Correcto
▲ Incorrecto
◐ Parcial
```

```swift
@AppStorage("semanticColorMode") var semanticColorMode: Bool = true

// Default false si hasAutism == true
// Configurable manualmente en Settings para cualquier usuario
```

---

### 6. Inicio predecible de sesión

Al iniciar cualquier sesión de práctica, mostrar siempre una pantalla de "preparación" que describe exactamente qué va a pasar antes de empezar. Sin sorpresas.

**UI:**
```
┌─────────────────────────────┐
│                             │
│  Sesión de hoy              │
│  Biología celular           │
│                             │
│  • 10 flashcards            │
│  • Preguntas abiertas       │
│  • Feedback después         │
│    de cada respuesta        │
│                             │
│  Puedes pausar cuando       │
│  quieras                    │
│                             │
│      [ Comenzar ]           │
│                             │
└─────────────────────────────┘
```

Esta pantalla solo aparece si `hasAutism == true`. Para otros usuarios la sesión inicia directamente.

---

### 7. Modo Clasificación — alternativo a flashcards

En lugar de pregunta-respuesta, el usuario arrastra conceptos a categorías correctas. Formato visual-sistemático que aprovecha la fortaleza de pensamiento por categorías común en TEA.

**UI:**
```
┌─────────────────────────────┐
│  Arrastra cada concepto     │
│  a su categoría             │
│                             │
│  Fase Clara  │  Fase Oscura │
│  ──────────  │  ──────────  │
│              │              │
│              │              │
│                             │
│  [ ATP ]  [ Luz ]  [ CO₂ ] │
│  [ Cloroplasto ]  [ NADPH ] │
└─────────────────────────────┘
```

Foundation Models genera las categorías y los conceptos. El resultado se evalúa y guarda como `attempt` normal en SwiftData — compatible con el mapa de lagunas.

---

## Dislexia

### 1. Audio-First Mode

La app funciona completamente por voz. Foundation Models lee la pregunta en voz alta con `AVSpeechSynthesizer`, el usuario responde hablando con `SFSpeechRecognizer`, Foundation Models evalúa y responde también por audio. El usuario nunca necesita leer ni escribir.

**Activación:** automático si `hasDyslexia == true`. Toggle manual disponible en Settings.

**UI en Audio-First Mode:**
```
┌─────────────────────────────┐
│                             │
│         🎧                  │
│                             │
│   Escuchando pregunta...    │
│                             │
│   ──────────────────────    │
│                             │
│   [ 🎤 Mantén para         │
│      responder ]            │
│                             │
│   [ 👁 Ver texto ]          │
│                             │
└─────────────────────────────┘
```

El botón "Ver texto" siempre está disponible — el modo audio no oculta el texto, solo lo hace secundario.

---

### 2. Texto sincronizado con audio

Cuando Foundation Models lee la pregunta, cada palabra se resalta en pantalla al pronunciarse. Ruta visual y auditiva simultáneas.

**Implementación con AVSpeechSynthesizerDelegate:**
```swift
class SpeechHighlighter: NSObject, AVSpeechSynthesizerDelegate {
    @Published var highlightedRange: NSRange?

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async {
            self.highlightedRange = characterRange
        }
    }
}

// En la vista, resaltar la palabra actual:
// Usar AttributedString con fondo amarillo en el rango highlightedRange
```

---

### 3. Tipografía adaptada automáticamente

Cuando `hasDyslexia == true`, aplicar automáticamente:

```swift
// Modificadores a aplicar en toda la app para dislexia:
.lineSpacing(8)           // Mayor interlineado
.tracking(0.5)            // Mayor espaciado entre letras
.font(.system(size: 18))  // Tamaño mínimo de texto
// Siempre respetar Dynamic Type del sistema además de estos valores
```

Disponible también como toggle manual en Settings → Apariencia → "Tipografía para dislexia".

---

### 4. Preguntas cortas por defecto

El prompt de generación de flashcards incluye instrucción adicional para perfil dislexia:

```
Las preguntas deben tener máximo 15 palabras.
Una sola idea por pregunta.
Sin oraciones subordinadas ni cláusulas compuestas.
Usar vocabulario directo.
```

---

### 5. Botón de audio prominente en flashcard

Para usuarios con `hasDyslexia == true`, el botón de escuchar la pregunta en voz alta es el elemento más grande de la tarjeta, encima del texto. No escondido en un menú.

**UI flashcard con dislexia:**
```
┌─────────────────────────────┐
│                             │
│  ┌─────────────────────┐    │
│  │  🔊 Escuchar        │    │  ← botón grande y prominente
│  └─────────────────────┘    │
│                             │
│  ¿Cuál es la función        │
│  del cloroplasto?           │
│                             │
│  ┌─────────────────────┐    │
│  │ 🎤 Responder        │    │  ← Speech to Text como opción principal
│  └─────────────────────┘    │
│                             │
│  o escribe tu respuesta...  │  ← campo de texto secundario
│                             │
└─────────────────────────────┘
```

---

### 6. Pizarra como método recomendado activamente

Para usuarios con `hasDyslexia == true`, al inicio de cada sesión mostrar una sugerencia activa de usar la pizarra en lugar de texto para responder.

**UI:**
```
┌─────────────────────────────┐
│  💡 Tip para ti             │
│                             │
│  Dibujar conceptos ayuda    │
│  a recordarlos mejor que    │
│  escribirlos.               │
│                             │
│  Puedes usar la pizarra     │
│  para responder esta        │
│  sesión.                    │
│                             │
│  [ Usar pizarra ]           │
│  [ Responder con texto ]    │
└─────────────────────────────┘
```

Este modal aparece máximo una vez por sesión. Tiene un toggle en Settings para desactivarlo si el usuario ya no quiere verlo.

---

### 7. Feedback en audio siempre

Para `hasDyslexia == true`, el feedback de Foundation Models se lee automáticamente en voz alta al aparecer. El usuario no necesita leerlo.

```swift
// Al mostrar feedback:
if hasDyslexia {
    speechSynthesizer.speak(AVSpeechUtterance(string: feedback.text))
}
```

---

## Prompts de Foundation Models por perfil

Estos son los system prompts que se construyen dinámicamente según el perfil del usuario. Se arman antes de cada llamada a Foundation Models concatenando las instrucciones base con las instrucciones del perfil.

### Prompt base — todos los usuarios
```
Eres un tutor educativo que evalúa respuestas de estudio.
Sé específico, honesto y constructivo.
Responde siempre en el mismo idioma que el usuario.
```

### Instrucciones adicionales para TDAH
```
El usuario tiene TDAH. Sigue estas reglas estrictamente:
- El feedback debe tener máximo 2 oraciones
- Si hay múltiples errores, reporta solo el más importante
- Comienza siempre reconociendo algo correcto antes de señalar errores
- Usa lenguaje energético y directo, nunca neutro o plano
- Nunca uses listas de múltiples puntos
```

### Instrucciones adicionales para TEA
```
El usuario está en el espectro autista. Sigue estas reglas estrictamente:
- Usa lenguaje completamente literal y concreto
- Nunca uses metáforas, sarcasmo, ironía o expresiones idiomáticas
- El feedback siempre sigue este formato exacto:
  Estado: [Correcto / Incorrecto / Parcial]
  Mencionaste: [lista de conceptos correctos]
  Faltó: [lista de conceptos omitidos]
  Próxima vez recuerda: [una sola oración]
- Nunca te desvíes de este formato aunque el contenido cambie
- Da primero el resultado (correcto/incorrecto) y luego el detalle
```

### Instrucciones adicionales para dislexia
```
El usuario tiene dislexia. Sigue estas reglas estrictamente:
- El feedback debe tener máximo 2 oraciones cortas
- Usa vocabulario simple y directo
- Nunca uses oraciones compuestas o subordinadas
- Las preguntas que generes deben tener máximo 15 palabras
- Una sola idea por pregunta u oración
```

### Construcción dinámica del prompt en Swift
```swift
func buildSystemPrompt(profile: UserProfile) -> String {
    var prompt = """
    Eres un tutor educativo que evalúa respuestas de estudio.
    Sé específico, honesto y constructivo.
    Responde siempre en el mismo idioma que el usuario.
    """

    if profile.accessibilityNeeds.contains("adhd") {
        prompt += """
        \nEl usuario tiene TDAH:
        - Feedback máximo 2 oraciones
        - Solo el error más importante
        - Empieza reconociendo algo correcto
        - Lenguaje directo y energético
        """
    }

    if profile.accessibilityNeeds.contains("autism") {
        prompt += """
        \nEl usuario está en el espectro autista:
        - Lenguaje completamente literal
        - Sin metáforas ni sarcasmo
        - Formato fijo: Estado / Mencionaste / Faltó / Próxima vez
        - Resultado primero, detalle después
        """
    }

    if profile.accessibilityNeeds.contains("dyslexia") {
        prompt += """
        \nEl usuario tiene dislexia:
        - Máximo 2 oraciones en el feedback
        - Vocabulario simple
        - Sin oraciones compuestas
        """
    }

    return prompt
}
```

---

## Prompt para Cursor

Pega esto directamente en Cursor:

---

Implementa las siguientes funcionalidades de accesibilidad en la app SwiftUI. Todas las funciones se activan leyendo `@AppStorage("accessibilityNeeds")` que contiene un string separado por comas.

Crear este helper en un archivo `AccessibilityProfile.swift`:
```swift
struct AccessibilityProfile {
    @AppStorage("accessibilityNeeds") var needs: String = ""
    var hasADHD: Bool { needs.contains("adhd") }
    var hasAutism: Bool { needs.contains("autism") }
    var hasDyslexia: Bool { needs.contains("dyslexia") }
    var hasLowVision: Bool { needs.contains("low_vision") }
}
```

**TDAH — implementar:**

1. `SessionBlockView`: al completar 3 flashcards mostrar pantalla de pausa con botones "Continuar" y "Terminar por hoy". El número 3 viene de `UserProfile.sessionBlockSize`.

2. Focus Mode: `@AppStorage("focusMode")` booleano. Cuando es true, la vista de flashcard oculta NavigationBar, ProgressBar y cualquier elemento que no sea la pregunta, campo de respuesta y botón enviar. Activar por defecto si `hasADHD`.

3. `StreakView`: componente que muestra "🔥 N seguidas". Al llegar a 5, mostrar sheet con opción de activar Modo Difícil. Guardar `currentStreak: Int` en `UserProfile` en SwiftData.

4. `SessionTimerView`: barra que crece mostrando tiempo invertido en la sesión. Usar `TimelineView(.animation)`. Nunca mostrar tiempo restante. Solo aparece si `!hasAutism`.

5. `StoryModeView`: vista alternativa a flashcards. Muestra una historia corta generada por Foundation Models con los conceptos del estudio, seguida de preguntas. Disponible como opción al iniciar sesión.

**TEA — implementar:**

1. `StudyRoutineView` en Settings: lista editable y reordenable de estudios con número de flashcards por sesión. Guardar como array de `StudyRoutine` en SwiftData. Si `hasAutism` y hay rutina configurada, al abrir la app iniciar la rutina directamente.

2. `SessionPreviewView`: pantalla que aparece antes de cada sesión si `hasAutism`. Muestra exactamente qué estudios, cuántas flashcards y qué tipo de preguntas habrá. Botón "Comenzar" para iniciar.

3. `SpecialInterestsView` en Settings: lista editable de temas de interés del usuario. Guardar como `[String]` en `UserProfile`. Usar en el prompt de Foundation Models cuando se genera explicación de laguna.

4. `ClassificationModeView`: vista alternativa a flashcards con drag and drop de conceptos a categorías. Foundation Models genera categorías y conceptos en JSON. El resultado se guarda como `attempt` en SwiftData igual que una flashcard normal.

5. Toggle `semanticColorMode` en Settings. Default `false` si `hasAutism`. Cuando está desactivado, reemplazar colores verde/rojo por formas geométricas (■ correcto, ▲ incorrecto, ◐ parcial) en toda la app.

6. Eliminar para `hasAutism`: timers de inactividad, mensajes de "¿sigues ahí?", notificaciones de racha perdida, tiempo transcurrido en sesión.

**Dislexia — implementar:**

1. `AudioFirstMode`: cuando está activo, la pregunta de la flashcard se lee automáticamente con `AVSpeechSynthesizer` al aparecer. El botón principal de respuesta es `SFSpeechRecognizer` (micrófono). El campo de texto existe pero es secundario. Activar por defecto si `hasDyslexia`.

2. `SpeechHighlighter`: clase `NSObject` que implementa `AVSpeechSynthesizerDelegate`. En `willSpeakRangeOfSpeechString` publicar el rango actual. En la vista de flashcard, usar `AttributedString` para resaltar la palabra que se está pronunciando con fondo amarillo claro.

3. Aplicar estos modificadores en toda la app cuando `hasDyslexia`:
   - `.lineSpacing(8)`
   - `.tracking(0.5)`
   - Fuente mínima de 18pt respetando Dynamic Type

4. En la vista de flashcard con `hasDyslexia`, el botón de audio (🔊) debe ser el elemento más grande y estar encima del texto de la pregunta. El botón de micrófono para responder debe ser más prominente que el campo de texto.

5. `DrawingModesuggestionView`: modal que aparece una vez por sesión si `hasDyslexia`, sugiriendo usar la pizarra. Botones "Usar pizarra" y "Responder con texto". Toggle en Settings para desactivarlo permanentemente.

6. Feedback automático por audio: si `hasDyslexia`, al mostrar el feedback de Foundation Models llamar automáticamente a `AVSpeechSynthesizer` para leerlo en voz alta.

**Prompts de Foundation Models — implementar:**

Crear `PromptBuilder.swift` con función `buildSystemPrompt(needs: String) -> String` que construye el prompt base y concatena instrucciones adicionales según los valores en el string de necesidades. Ver sección "Construcción dinámica del prompt" del documento. Usar este builder en todas las llamadas a Foundation Models de la app.

**Reglas globales para todos los perfiles:**
- Respetar `@Environment(\.accessibilityReduceMotion)` — si está activo, sin animaciones en ninguna transición
- Todos los elementos interactivos con `.accessibilityLabel` descriptivo en inglés y español
- Botones con `.frame(minWidth: 44, minHeight: 44)` mínimo
- Nunca avance automático entre flashcards — siempre requiere tap explícito del usuario
- Feedback háptico en cada evaluación: `UIImpactFeedbackGenerator(style: .light)` para correcto, `UIImpactFeedbackGenerator(style: .medium)` para incorrecto
