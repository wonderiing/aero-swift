# Onboarding & Perfil de Usuario
> Stack: SwiftUI · SwiftData · @AppStorage  
> Sin login. Todo local. Las preferencias se guardan en SwiftData y @AppStorage.

---

## Tabla de contenidos

1. [Modelo de datos](#modelo-de-datos)
2. [Flujo de onboarding](#flujo-de-onboarding)
   - [Pantalla 1 — Bienvenida](#pantalla-1--bienvenida)
   - [Pantalla 2 — Estilo de sesión](#pantalla-2--estilo-de-sesión)
   - [Pantalla 3 — Accesibilidad](#pantalla-3--accesibilidad)
   - [Pantalla 4 — Tu nombre](#pantalla-4--tu-nombre)
3. [Settings — editar preferencias](#settings)
4. [Cómo las preferencias afectan la app](#cómo-las-preferencias-afectan-la-app)
5. [Prompt para Cursor](#prompt-para-cursor)

---

## Modelo de datos

Todo se guarda localmente con `@AppStorage` para preferencias simples y SwiftData para el perfil completo.

### @AppStorage keys

```swift
// Controla si el onboarding ya fue completado
@AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

// Nombre del usuario
@AppStorage("userName") var userName: String = ""

// Estilo de sesión — guardado como string separado por comas
@AppStorage("sessionStyle") var sessionStyle: String = ""
// Valores posibles: "short_sessions", "long_sessions", "prefer_audio", "prefer_writing"

// Accesibilidad — guardado como string separado por comas
@AppStorage("accessibilityNeeds") var accessibilityNeeds: String = ""
// Valores posibles: "adhd", "autism", "dyslexia", "low_vision"
```

### SwiftData Model — UserProfile

```swift
@Model
class UserProfile {
    var name: String
    var sessionStyle: [String]       // ["short_sessions", "prefer_audio"]
    var accessibilityNeeds: [String] // ["adhd", "dyslexia"]
    var createdAt: Date
    var updatedAt: Date

    init(name: String) {
        self.name = name
        self.sessionStyle = []
        self.accessibilityNeeds = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

---

## Flujo de onboarding

El onboarding se muestra una sola vez cuando `hasCompletedOnboarding == false`. Son 4 pantallas navegables con botón "Siguiente". Al terminar se setea `hasCompletedOnboarding = true` y nunca vuelve a aparecer.

```
Pantalla 1 — Bienvenida
      ↓
Pantalla 2 — Estilo de sesión
      ↓
Pantalla 3 — Accesibilidad  (tiene botón "Saltar")
      ↓
Pantalla 4 — Tu nombre
      ↓
App principal
```

---

### Pantalla 1 — Bienvenida

**Propósito:** presentar la app, sin opciones ni formularios.

```
┌─────────────────────────────┐
│                             │
│         [ícono app]         │
│                             │
│   Aprende con lo que        │
│   ya tienes                 │
│                             │
│   Sube tus notas y PDFs.    │
│   La IA genera flashcards,  │
│   detecta en qué fallas     │
│   y adapta tu estudio.      │
│                             │
│                             │
│      [ Comenzar →  ]        │
│                             │
└─────────────────────────────┘
```

**Elementos:**
- Ícono de la app centrado
- Título grande — fuente Display / Bold
- Subtítulo — fuente Body / Regular, color secundario
- Botón primario "Comenzar" en la parte inferior

---

### Pantalla 2 — Estilo de sesión

**Propósito:** entender cómo prefiere estudiar el usuario.

```
┌─────────────────────────────┐
│                             │
│  ¿Cómo prefieres            │
│  estudiar?                  │
│                             │
│  Puedes cambiarlo           │
│  cuando quieras             │
│                             │
│  ┌──────────┐ ┌──────────┐  │
│  │ ⏱        │ │ 📚       │  │
│  │ Sesiones │ │ Sesiones │  │
│  │ cortas   │ │ largas   │  │
│  │ 10-15min │ │ Sin lím. │  │
│  └──────────┘ └──────────┘  │
│                             │
│  ┌──────────┐ ┌──────────┐  │
│  │ 🎧       │ │ ✍️       │  │
│  │ Prefiero │ │ Prefiero │  │
│  │ escuchar │ │ leer y   │  │
│  │          │ │ escribir │  │
│  └──────────┘ └──────────┘  │
│                             │
│      [ Siguiente → ]        │
│                             │
└─────────────────────────────┘
```

**Comportamiento de las tarjetas:**
- Selección múltiple — el usuario puede elegir varias
- Tarjeta no seleccionada: fondo `secondarySystemBackground`, borde `systemGray4`
- Tarjeta seleccionada: fondo `systemBlue` con opacidad 0.1, borde `systemBlue`, checkmark en esquina superior derecha
- Mínimo 0 selecciones para avanzar — todas son opcionales

**Opciones y sus keys:**

| Ícono SF Symbol | Título | Descripción | Key |
|---|---|---|---|
| `timer` | Sesiones cortas | 10–15 min | `short_sessions` |
| `book.fill` | Sesiones largas | Sin límite de tiempo | `long_sessions` |
| `headphones` | Prefiero escuchar | Audio en flashcards | `prefer_audio` |
| `pencil` | Prefiero leer y escribir | Modo texto | `prefer_writing` |

---

### Pantalla 3 — Accesibilidad

**Propósito:** detectar necesidades específicas para adaptar la experiencia.

```
┌─────────────────────────────┐
│                    [Saltar] │
│                             │
│  ¿Algo que debamos          │
│  saber?                     │
│                             │
│  Esto nos ayuda a adaptar   │
│  la app para ti             │
│                             │
│  ┌─────────────────────┐    │
│  │ 🧠  Tengo TDAH      │    │
│  │ Me cuesta mantener  │    │
│  │ el foco             │ ✓  │
│  └─────────────────────┘    │
│                             │
│  ┌─────────────────────┐    │
│  │ 🎯  Estoy en el     │    │
│  │ espectro autista    │    │
│  │ Prefiero interfaces │    │
│  │ predecibles         │    │
│  └─────────────────────┘    │
│                             │
│  ┌─────────────────────┐    │
│  │ 📖  Tengo dislexia  │    │
│  │ Me cuesta leer      │    │
│  │ textos largos       │    │
│  └─────────────────────┘    │
│                             │
│  ┌─────────────────────┐    │
│  │ 👁  Baja visión     │    │
│  │ Necesito texto más  │    │
│  │ grande              │    │
│  └─────────────────────┘    │
│                             │
│      [ Siguiente → ]        │
│                             │
└─────────────────────────────┘
```

**Comportamiento:**
- Botón "Saltar" en esquina superior derecha — avanza sin guardar nada
- Selección múltiple — el usuario puede tener TDAH y dislexia al mismo tiempo
- Tarjeta seleccionada igual que pantalla 2
- 0 selecciones es válido para avanzar

**Opciones y sus keys:**

| Ícono SF Symbol | Título | Descripción | Key |
|---|---|---|---|
| `brain.head.profile` | Tengo TDAH | Me cuesta mantener el foco por mucho tiempo | `adhd` |
| `figure.mind.and.body` | Estoy en el espectro autista | Prefiero interfaces predecibles y lenguaje claro | `autism` |
| `text.book.closed` | Tengo dislexia | Me cuesta leer textos largos | `dyslexia` |
| `eye` | Baja visión | Necesito texto más grande o alto contraste | `low_vision` |

---

### Pantalla 4 — Tu nombre

**Propósito:** personalizar la experiencia con el nombre del usuario. Es el único dato que se pide.

```
┌─────────────────────────────┐
│                             │
│                             │
│  ¿Cómo te llamamos?         │
│                             │
│  ┌─────────────────────┐    │
│  │ Tu nombre           │    │
│  └─────────────────────┘    │
│                             │
│  Solo lo usamos para        │
│  personalizar tu            │
│  experiencia                │
│                             │
│                             │
│      [ Empezar →  ]         │
│                             │
└─────────────────────────────┘
```

**Comportamiento:**
- Campo de texto con placeholder "Tu nombre"
- El nombre es opcional — si está vacío se guarda "Estudiante"
- Botón "Empezar" guarda todo y setea `hasCompletedOnboarding = true`
- Al presionar "Empezar": crear el `UserProfile` en SwiftData, guardar `@AppStorage` keys, navegar a la app principal

---

## Settings

El usuario puede modificar cualquier preferencia del onboarding desde Settings. La pantalla de Settings tiene tres secciones.

```
┌─────────────────────────────┐
│  ← Configuración            │
│                             │
│  PERFIL                     │
│  ┌─────────────────────┐    │
│  │ Nombre    Carlos  > │    │
│  └─────────────────────┘    │
│                             │
│  ESTILO DE ESTUDIO          │
│  ┌─────────────────────┐    │
│  │ ⏱ Sesiones cortas ✓ │    │
│  │ 📚 Sesiones largas  │    │
│  │ 🎧 Prefiero escuchar│    │
│  │ ✍️ Prefiero escribir│    │
│  └─────────────────────┘    │
│                             │
│  ACCESIBILIDAD              │
│  ┌─────────────────────┐    │
│  │ 🧠 TDAH           ✓ │    │
│  │ 🎯 Autismo          │    │
│  │ 📖 Dislexia       ✓ │    │
│  │ 👁 Baja visión      │    │
│  └─────────────────────┘    │
│                             │
│  APARIENCIA                 │
│  ┌─────────────────────┐    │
│  │ Modo Focus    OFF ○ │    │
│  │ Reducir movimiento  │    │
│  │              AUTO ○ │    │
│  │ Tamaño de texto   > │    │
│  └─────────────────────┘    │
│                             │
└─────────────────────────────┘
```

**Sección PERFIL:**
- Nombre editable inline con tap

**Sección ESTILO DE ESTUDIO:**
- Lista de toggles o checkmarks — mismas opciones que pantalla 2 del onboarding
- Cambios se aplican inmediatamente y se guardan en SwiftData

**Sección ACCESIBILIDAD:**
- Lista de toggles — mismas opciones que pantalla 3 del onboarding
- Cambios se aplican inmediatamente

**Sección APARIENCIA:**
- `Modo Focus` — toggle manual, override de la preferencia automática
- `Reducir movimiento` — tres opciones: AUTO (sigue el sistema), ON, OFF
- `Tamaño de texto` — slider o selector: Normal / Grande / Muy grande

---

## Cómo las preferencias afectan la app

### `short_sessions`
- Default de flashcards por sesión: 10 (en lugar de ilimitado)
- Muestra barra de progreso siempre visible: "3 de 10"
- Sugiere tomar un descanso al completar la sesión

### `prefer_audio`
- Text to Speech activado por defecto en todas las flashcards
- Botón de audio prominente en la tarjeta, no escondido en menú
- Al revelar la respuesta correcta, se lee en voz alta automáticamente

### `adhd`
- Modo Focus activado por defecto
- Barra de progreso siempre visible
- Racha visible: "🔥 3 seguidas"
- Prompt de Foundation Models incluye instrucción: *"El feedback debe ser breve, directo y comenzar siempre reconociendo lo que el usuario hizo bien antes de señalar errores"*

### `autism`
- Animaciones reducidas por defecto (independiente del sistema)
- Nunca avance automático entre flashcards
- Transiciones siempre predecibles: mismo sonido y color en cada evaluación
- Prompt de Foundation Models incluye instrucción: *"Usa lenguaje directo y concreto. Evita metáforas, sarcasmo o lenguaje ambiguo. En lugar de 'casi lo tienes' di exactamente qué faltó"*

### `dyslexia`
- Tamaño de texto una escala mayor al default
- Mayor espaciado entre líneas (`lineSpacing`)
- Text to Speech activado por defecto
- Preguntas de flashcards más cortas — instrucción en el prompt de generación: *"Las preguntas deben ser cortas y directas, sin oraciones compuestas largas"*

### `low_vision`
- Texto en tamaño máximo
- Alto contraste activado
- Íconos más grandes en navegación

---

## Prompt para Cursor

Pega esto directamente en Cursor:

---

Crea un flujo de onboarding en SwiftUI de 4 pantallas. Usar `TabView` con `PageTabViewStyle` o navegación con botón "Siguiente" y estado `@State var currentStep: Int = 0`.

**Datos a guardar:**
- `@AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool`
- `@AppStorage("userName") var userName: String`
- `@AppStorage("sessionStyle") var sessionStyle: String` — valores separados por coma
- `@AppStorage("accessibilityNeeds") var accessibilityNeeds: String` — valores separados por coma
- Crear SwiftData model `UserProfile` con campos: `name: String`, `sessionStyle: [String]`, `accessibilityNeeds: [String]`, `createdAt: Date`, `updatedAt: Date`

**Pantalla 1 — Bienvenida:**
Ícono de app centrado, título grande "Aprende con lo que ya tienes", subtítulo "Sube tus notas y PDFs. La IA genera flashcards, detecta en qué fallas y adapta tu estudio.", botón primario "Comenzar" en la parte inferior.

**Pantalla 2 — Estilo de sesión:**
Título "¿Cómo prefieres estudiar?", subtítulo "Puedes cambiarlo cuando quieras". Grid 2x2 de tarjetas seleccionables con SF Symbols. Selección múltiple. Opciones: `short_sessions` (SF: `timer`, "Sesiones cortas", "10–15 min"), `long_sessions` (SF: `book.fill`, "Sesiones largas", "Sin límite"), `prefer_audio` (SF: `headphones`, "Prefiero escuchar", "Audio en flashcards"), `prefer_writing` (SF: `pencil`, "Prefiero escribir", "Modo texto"). Tarjeta seleccionada: fondo `systemBlue` opacidad 0.1, borde `systemBlue`, checkmark en esquina superior derecha. Botón "Siguiente" siempre habilitado aunque no haya selección.

**Pantalla 3 — Accesibilidad:**
Botón "Saltar" en esquina superior derecha que avanza sin guardar nada. Título "¿Algo que debamos saber?", subtítulo "Esto nos ayuda a adaptar la app para ti". Lista vertical de tarjetas seleccionables con SF Symbols y descripción. Selección múltiple. Opciones: `adhd` (SF: `brain.head.profile`, "Tengo TDAH", "Me cuesta mantener el foco por mucho tiempo"), `autism` (SF: `figure.mind.and.body`, "Estoy en el espectro autista", "Prefiero interfaces predecibles y lenguaje claro"), `dyslexia` (SF: `text.book.closed`, "Tengo dislexia", "Me cuesta leer textos largos"), `low_vision` (SF: `eye`, "Baja visión", "Necesito texto más grande"). Mismo estilo de selección que pantalla 2.

**Pantalla 4 — Nombre:**
Título "¿Cómo te llamamos?", campo de texto con placeholder "Tu nombre", texto secundario "Solo lo usamos para personalizar tu experiencia". Botón "Empezar" que al presionar: guarda el nombre en @AppStorage (si está vacío guardar "Estudiante"), crea el UserProfile en SwiftData con las selecciones de pantallas 2 y 3, setea `hasCompletedOnboarding = true`, navega a la app principal.

**Settings — SettingsView:**
Crear una vista `SettingsView` con tres secciones en un `List` con `Form`:

Sección "Perfil": campo editable para el nombre del usuario. Al cambiar, actualizar @AppStorage y SwiftData.

Sección "Estilo de estudio": lista de filas con toggle o checkmark para cada opción de la pantalla 2 del onboarding. Al cambiar, actualizar @AppStorage y SwiftData inmediatamente.

Sección "Accesibilidad": lista de filas con toggle para cada opción de la pantalla 3. Al cambiar, actualizar @AppStorage y SwiftData inmediatamente.

Sección "Apariencia": toggle "Modo Focus" guardado en `@AppStorage("focusMode")`. Picker "Reducir movimiento" con opciones AUTO/ON/OFF guardado en `@AppStorage("reduceMotion")`. Picker "Tamaño de texto" con opciones Normal/Grande/Muy grande guardado en `@AppStorage("textSize")`.

**Comportamiento global:**
- Respetar `@Environment(\.accessibilityReduceMotion)` para transiciones — si está activo, sin animaciones
- Usar `.dynamicTypeSize` para respetar Dynamic Type del sistema
- Todos los textos con fuentes semánticas de SwiftUI (`.title`, `.body`, `.caption`) nunca tamaños fijos
- VoiceOver: todos los elementos interactivos con `.accessibilityLabel` descriptivo
- La preferencia `focusMode` debe ser accesible como `@AppStorage` desde cualquier vista de la app para condicionar qué elementos se muestran
