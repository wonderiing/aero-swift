# Flujo Swift — Aero Study App

> Este documento describe el flujo completo del frontend iOS, pantalla por pantalla, incluyendo la integración con Foundation Models, el backend, y sugerencias de mejora.

---

## Tabla de contenidos

1. [Visión general](#visión-general)
2. [Pantallas y flujo](#pantallas-y-flujo)
3. [Referencia de DTOs y Headers](#referencia-de-dtos-y-headers)
4. [Integración con Foundation Models](#integración-con-foundation-models)
5. [Mejoras propuestas](#mejoras-propuestas)
6. [Decisiones abiertas](#decisiones-abiertas)

---

## Visión general

```
┌──────────┐    ┌──────────┐    ┌────────────┐    ┌───────────────┐    ┌──────────────┐
│  Auth    │───→│  Studies │───→│  Resources │───→│  Flashcards   │───→│  Practice    │
│  Screen  │    │  List    │    │  Manager   │    │  Generator    │    │  Session     │
└──────────┘    └──────────┘    └────────────┘    └───────────────┘    └──────────────┘
                     │                                                       │
                     │                                                       ▼
                     │                                               ┌──────────────┐
                     └──────────────────────────────────────────────→│  Stats /     │
                                                                     │  Gaps        │
                                                                     └──────────────┘
```

**Principio clave:** Foundation Models corre **on-device** para generar flashcards y evaluar respuestas. El backend es un **almacén tonto** — no evalúa ni genera nada, solo persiste datos y calcula gaps por agregación matemática.

---

## Pantallas y flujo

### 1. Auth Screen

**Acciones:** Register / Login

#### `POST /auth/register`
> 🔓 No requiere JWT · Rate limit: 5 req / 15 min

```
Headers:
  Content-Type: application/json
```

```json
// Body (RegisterDto)
{
  "username": "Carlos",        // string, requerido, min 4 chars
  "email": "carlos@mail.com",  // string, requerido, formato email
  "password": "12345678"       // string, requerido, min 8 chars
}
```

```json
// Response 201
{
  "access_token": "eyJhbGci...",
  "refresh_token": "eyJhbGci..."
}
```

---

#### `POST /auth/login`
> 🔓 No requiere JWT · Rate limit: 5 req / 15 min

```
Headers:
  Content-Type: application/json
```

```json
// Body (LoginDto)
{
  "email": "carlos@mail.com",  // string, requerido, formato email
  "password": "12345678"       // string, requerido
}
```

```json
// Response 200
{
  "access_token": "eyJhbGci...",
  "refresh_token": "eyJhbGci..."
}
```

---

#### `POST /auth/refresh`
> 🔑 Requiere `refresh_token` como Bearer · Rate limit: 10 req / 1 min

```
Headers:
  Content-Type: application/json
  Authorization: Bearer <refresh_token>
```

```json
// Body: vacío

// Response 200
{
  "access_token": "eyJhbGci...",
  "refresh_token": "eyJhbGci..."
}
```

---

#### `POST /auth/logout`
> 🔑 Requiere `access_token` como Bearer

```
Headers:
  Authorization: Bearer <access_token>
```

```json
// Body: vacío

// Response 200
{ "message": "Logged out" }
```

**Flujo de tokens en Swift:**
- Guardar `access_token` y `refresh_token` en **Keychain**
- Interceptor de red: si un request falla con `401`, intentar `POST /auth/refresh` automáticamente con el `refresh_token`
- Si el refresh falla → volver a login
- Todos los endpoints de aquí en adelante requieren `Authorization: Bearer <access_token>`

> [!TIP]
> Implementar biometric auth (Face ID / Touch ID) para sesiones recurrentes. No necesitas endpoint nuevo — solo desbloquear los tokens almacenados en Keychain tras verificación biométrica.

---

### 2. Studies List (Home)

**Lo que ve el usuario:** Lista de todos sus estudios con un resumen visual.

#### `GET /studies`
> 🔑 JWT requerido

```
Headers:
  Authorization: Bearer <access_token>

Query params opcionales:
  ?limit=10&offset=0
```

```json
// Response 200
[
  {
    "id": "uuid",
    "title": "Biología celular",
    "description": "Apuntes del parcial 2",
    "createdAt": "2026-04-01T00:00:00Z"
  }
]
```

---

#### `POST /studies`
> 🔑 JWT requerido

```
Headers:
  Content-Type: application/json
  Authorization: Bearer <access_token>
```

```json
// Body (CreateStudyDto)
{
  "title": "Biología celular",      // string, requerido, min 4 chars
  "description": "Apuntes del parcial 2"  // string, requerido, min 5 chars
}
```

```json
// Response 201
{
  "id": "uuid",
  "title": "Biología celular",
  "description": "Apuntes del parcial 2"
}
```

---

#### `GET /studies/:studyId`
> 🔑 JWT requerido

```
Headers:
  Authorization: Bearer <access_token>

Params:
  studyId: UUID
```

```json
// Response 200
{
  "id": "uuid",
  "title": "Biología celular",
  "description": "Apuntes del parcial 2",
  "createdAt": "2026-04-01T00:00:00Z"
}
```

---

#### `DELETE /studies/:studyId`
> 🔑 JWT requerido · ⚠️ Borra todo en cascada (resources, flashcards, attempts)

```
Headers:
  Authorization: Bearer <access_token>

Params:
  studyId: UUID
```

```json
// Response 200 (sin body)
```

**Cada card de estudio muestra:**
- Título y descripción
- Mini-barra de progreso (accuracy global del estudio)
- Número de flashcards pendientes de repaso (badge)
- Fecha de última sesión de práctica

---

### 3. Study Detail

**Lo que ve el usuario:** Vista principal del estudio con 3 tabs o secciones.

```
┌─────────────────────────────────────────────┐
│  📚 Biología Celular                        │
│─────────────────────────────────────────────│
│  [Recursos]  [Flashcards]  [Progreso]       │
│                                              │
│         contenido del tab activo             │
│                                              │
│  ┌─────────────────────────────────┐        │
│  │  ▶  Iniciar sesión de repaso    │        │
│  └─────────────────────────────────┘        │
└─────────────────────────────────────────────┘
```

El botón principal "Iniciar sesión de repaso" siempre visible. Muestra cuántas cards están pendientes.

---

### 4. Tab: Recursos

#### `GET /studies/:studyId/resources`
> 🔑 JWT requerido

```
Headers:
  Authorization: Bearer <access_token>

Params:
  studyId: UUID
```

```json
// Response 200
[
  {
    "id": "uuid",
    "title": "Clase 3 - Fotosíntesis",
    "content": "La fotosíntesis es el proceso...",
    "sourceName": null,
    "createdAt": "2026-04-01T00:00:00Z"
  }
]
```

---

#### `POST /studies/:studyId/resources`
> 🔑 JWT requerido

```
Headers:
  Content-Type: application/json
  Authorization: Bearer <access_token>

Params:
  studyId: UUID
```

**Crear recurso — 3 formas de entrada:**

| Método | Flujo en Swift | Qué va en `sourceName` |
|--------|---------------|------------------------|
| **Texto libre** | Editor de texto in-app | `null` (no mandarlo) |
| **PDF** | `UIDocumentPickerViewController` → Vision Framework extrae texto | `"capitulo4_biologia.pdf"` |
| **Cámara / OCR** | `AVCaptureSession` → Vision `VNRecognizeTextRequest` | `"scan_foto.jpg"` |

```json
// Body (CreateResourceDto) — Texto libre
{
  "title": "Clase 3 - Fotosíntesis",  // string, requerido, min 3 chars
  "content": "La fotosíntesis es..."   // string, requerido
}

// Body (CreateResourceDto) — PDF / OCR
{
  "title": "Capítulo 4",              // string, requerido, min 3 chars
  "content": "Texto extraído...",      // string, requerido
  "sourceName": "capitulo4.pdf"        // string, opcional
}
```

```json
// Response 201
{
  "id": "uuid",
  "title": "Capítulo 4",
  "content": "Texto extraído...",
  "sourceName": "capitulo4.pdf",
  "createdAt": "2026-04-02T00:00:00Z"
}
```

---

#### `GET /resources/:id`
> 🔑 JWT requerido

```
Headers:
  Authorization: Bearer <access_token>

Params:
  id: UUID
```

```json
// Response 200
{
  "id": "uuid",
  "title": "Clase 3 - Fotosíntesis",
  "content": "Contenido completo del recurso...",
  "sourceName": null,
  "createdAt": "2026-04-01T00:00:00Z"
}
```

---

#### `PATCH /resources/:id`
> 🔑 JWT requerido

```
Headers:
  Content-Type: application/json
  Authorization: Bearer <access_token>

Params:
  id: UUID
```

```json
// Body (UpdateResourceDto) — todos los campos son opcionales
{
  "title": "Clase 3 - Fotosíntesis (corregida)",  // string, opcional, min 3 chars
  "content": "Contenido actualizado..."             // string, opcional
}
```

```json
// Response 200: el recurso actualizado completo
```

> [!IMPORTANT]
> Todo el procesamiento de PDF y OCR ocurre **on-device** con Vision Framework. El backend solo recibe texto plano. Esto mantiene la latencia baja y la privacidad alta.

---

### 5. Tab: Flashcards

#### `GET /studies/:studyId/flashcards`
> 🔑 JWT requerido

```
Headers:
  Authorization: Bearer <access_token>

Params:
  studyId: UUID

Query params opcionales:
  ?resource_id=uuid   →  solo flashcards de ese recurso
```

```json
// Response 200
[
  {
    "id": "uuid",
    "question": "¿Cuál es la función del cloroplasto?",
    "answer": "Realizar la fotosíntesis...",
    "type": "open",
    "options": null,
    "conceptTags": ["cloroplasto", "fotosíntesis"],
    "nextReviewAt": "2026-04-05T00:00:00Z",
    "easeFactor": 2.5,
    "intervalDays": 1,
    "createdAt": "2026-04-01T00:00:00Z"
  }
]
```

---

#### `GET /studies/:studyId/flashcards/review-queue`
> 🔑 JWT requerido

Devuelve las flashcards que toca repasar **ahora** según SM-2 (`nextReviewAt <= now` o `nextReviewAt == null`).

```
Headers:
  Authorization: Bearer <access_token>

Params:
  studyId: UUID
```

```json
// Response 200
[
  {
    "id": "uuid",
    "question": "¿Dónde ocurre la fase oscura?",
    "answer": "En el estroma del cloroplasto.",
    "type": "multiple_choice",
    "options": {
      "correct": "En el estroma del cloroplasto",
      "distractors": ["En la membrana tilacoide", "En el núcleo", "En el citoplasma"]
    },
    "conceptTags": ["fase oscura", "cloroplasto"],
    "nextReviewAt": null,
    "easeFactor": 2.5,
    "intervalDays": 0,
    "createdAt": "2026-04-02T00:00:00Z"
  }
]
// Si el array viene vacío → no hay flashcards pendientes de repaso
```

---

#### `POST /studies/:studyId/flashcards`
> 🔑 JWT requerido

Guarda una flashcard individual.

```
Headers:
  Content-Type: application/json
  Authorization: Bearer <access_token>

Params:
  studyId: UUID
```

```json
// Body (CreateFlashcardDto)
{
  "question": "¿Cuál es la función del cloroplasto?",  // string, requerido
  "answer": "Realizar la fotosíntesis...",              // string, requerido
  "type": "open",                                       // "open" | "multiple-choice", opcional (default: "open")
  "options": null,                                      // objeto | null, opcional (requerido si type == "multiple-choice")
  "conceptTags": ["cloroplasto", "fotosíntesis"],       // string[], requerido
  "resourceId": "uuid"                                  // UUID, requerido — de qué recurso viene
}
```

Cuando `type` es `"multiple-choice"`, `options` debe ser:
```json
{
  "options": {
    "correct": "Respuesta correcta",
    "distractors": ["Opción falsa 1", "Opción falsa 2", "Opción falsa 3"]
  }
}
```

```json
// Response 201: la flashcard creada
```

---

#### `POST /studies/:studyId/flashcards/batch`
> 🔑 JWT requerido

Guarda un lote de flashcards. **Usar después de que Foundation Models genere todas las flashcards.**

```
Headers:
  Content-Type: application/json
  Authorization: Bearer <access_token>

Params:
  studyId: UUID
```

```json
// Body — Array de CreateFlashcardDto[]
[
  {
    "question": "¿Qué es la fotosíntesis?",
    "answer": "Proceso por el cual las plantas convierten luz en energía.",
    "type": "open",
    "options": null,
    "conceptTags": ["fotosíntesis"],
    "resourceId": "uuid"
  },
  {
    "question": "¿Dónde ocurre la fase oscura?",
    "answer": "En el estroma del cloroplasto.",
    "type": "multiple-choice",
    "options": {
      "correct": "En el estroma del cloroplasto",
      "distractors": ["En la membrana tilacoide", "En el núcleo", "En el citoplasma"]
    },
    "conceptTags": ["fase oscura", "cloroplasto"],
    "resourceId": "uuid"
  }
]
```

```json
// Response 201: Array de flashcards creadas
```

**Generar flashcards (Foundation Models on-device):**

```
┌────────────────────────────────────────────────────────────┐
│                  GENERACIÓN DE FLASHCARDS                   │
│                                                             │
│  1. Usuario selecciona 1 o más recursos                     │
│  2. Swift concatena el contenido de los recursos            │
│  3. Foundation Models genera las flashcards                 │
│  4. El usuario revisa, edita, elimina antes de guardar      │
│  5. Swift manda al backend:                                 │
│     POST /studies/:studyId/flashcards/batch                 │
│     con el array de CreateFlashcardDto[]                    │
└────────────────────────────────────────────────────────────┘
```

**Pantalla de revisión pre-guardado:**
- Lista editable de las flashcards generadas
- Poder eliminar las que no convencen
- Poder editar pregunta, respuesta, opciones, tags
- Botón "Guardar todas" → `POST .../flashcards/batch`

---

### 6. Sesión de práctica (Core Loop)

Este es **el corazón de la app**. El flujo es:

```
  1. Obtener contexto (2 requests paralelos)
     ├── GET /studies/:studyId/gaps
     └── GET /studies/:studyId/flashcards/review-queue

  2. Foundation Models prioriza el orden
     └── Input: flashcards + gaps → Output: orden óptimo

  3. Por cada flashcard → usuario responde → evaluar → guardar:
     └── POST /flashcards/:flashcardId/attempts

  4. Resumen de sesión
```

#### `POST /flashcards/:flashcardId/attempts`
> 🔑 JWT requerido

Guarda el resultado de una respuesta. **El backend actualiza automáticamente los campos SM-2 de la flashcard** (`nextReviewAt`, `easeFactor`, `intervalDays`).

```
Headers:
  Content-Type: application/json
  Authorization: Bearer <access_token>

Params:
  flashcardId: UUID
```

```json
// Body (CreateAttemptDto)
{
  "userAnswer": "El cloroplasto realiza la fotosíntesis usando la luz solar",  // string, opcional
  "isCorrect": true,                    // boolean, REQUERIDO
  "errorType": null,                    // "conceptual" | "memoria" | "confusion" | "incompleto" | null, opcional
  "missingConcepts": [],                // string[], opcional
  "incorrectConcepts": [],              // string[], opcional
  "feedback": "Correcto. Mencionaste los conceptos clave.",  // string, opcional
  "confidenceScore": 0.92              // float 0.0-1.0, opcional
}
```

**Ejemplo de respuesta incorrecta:**
```json
{
  "userAnswer": "La mitocondria hace la fotosíntesis",
  "isCorrect": false,
  "errorType": "conceptual",
  "missingConcepts": ["cloroplasto"],
  "incorrectConcepts": ["mitocondria"],
  "feedback": "La fotosíntesis ocurre en los cloroplastos, no en la mitocondria.",
  "confidenceScore": 0.25
}
```

**Ejemplo de opción múltiple (incorrecta):**
```json
{
  "userAnswer": "En el núcleo",
  "isCorrect": false,
  "errorType": "confusion",
  "missingConcepts": ["estroma"],
  "incorrectConcepts": ["núcleo"],
  "feedback": "La fase oscura ocurre en el estroma del cloroplasto, no en el núcleo.",
  "confidenceScore": 0.0
}
```

```json
// Response 201: el attempt creado
{
  "id": "uuid",
  "userAnswer": "...",
  "isCorrect": true,
  "errorType": null,
  "missingConcepts": [],
  "incorrectConcepts": [],
  "feedback": "...",
  "confidenceScore": 0.92,
  "answeredAt": "2026-04-04T12:30:00Z"
}
```

**Detalle del flujo por tipo de pregunta:**

```
Si type == "open":
  → Campo de texto + botón 🎙️ Speech-to-Text
  → Usuario escribe o dicta su respuesta
  → Foundation Models evalúa y genera el CreateAttemptDto
  → Si hay conceptos erróneos: mostrar explicación expandida
  → POST /flashcards/:flashcardId/attempts con el DTO

Si type == "multiple_choice":
  → Mostrar 4 opciones (shuffled)
  → Tap en opción → feedback inmediato
  → Foundation Models genera el CreateAttemptDto
  → POST /flashcards/:flashcardId/attempts con el DTO
```

**Speech-to-Text:**
- Usar `SFSpeechRecognizer` de Apple
- Idioma configurable (es-MX, en-US, etc.)
- Transcripción en tiempo real mientras el usuario habla
- Botón toggle 🎙️ junto al campo de texto

**Feedback expandido para preguntas abiertas:**

Cuando Foundation Models detecta un concepto erróneo o incompleto, la UI muestra:

```
┌─────────────────────────────────────────────┐
│  ❌ Tu respuesta tiene un error conceptual   │
│                                              │
│  Dijiste: "La mitocondria hace fotosíntesis" │
│                                              │
│  📖 Concepto: Fotosíntesis                   │
│  La fotosíntesis ocurre en los cloroplastos, │
│  no en la mitocondria. La mitocondria es     │
│  responsable de la respiración celular...    │
│                                              │
│  [Entendido]          [Explicar más]         │
└─────────────────────────────────────────────┘
```

El botón "Explicar más" hace otra llamada a Foundation Models para profundizar, **no requiere endpoint nuevo** — todo es on-device.

---

### 7. Tab: Progreso (Stats / Gaps)

#### `GET /studies/:studyId/attempts`
> 🔑 JWT requerido

```
Headers:
  Authorization: Bearer <access_token>

Params:
  studyId: UUID
```

```json
// Response 200
{
  "total": 45,
  "correct": 30,
  "accuracy": 0.67,
  "attempts": [
    {
      "id": "uuid",
      "userAnswer": "...",
      "isCorrect": true,
      "errorType": null,
      "feedback": "Correcto.",
      "confidenceScore": 0.92,
      "answeredAt": "2026-04-04T00:00:00Z",
      "flashcard": {
        "id": "uuid",
        "question": "¿Cuál es la función del cloroplasto?",
        "conceptTags": ["cloroplasto", "fotosíntesis"]
      }
    }
  ]
}
```

---

#### `GET /studies/:studyId/gaps`
> 🔑 JWT requerido

```
Headers:
  Authorization: Bearer <access_token>

Params:
  studyId: UUID
```

```json
// Response 200
{
  "study_id": "uuid",
  "total_attempts": 45,
  "gaps": [
    {
      "concept": "fase oscura",
      "error_rate": 0.78,
      "total_attempts": 9,
      "errors": 7,
      "dominant_error_type": "conceptual",
      "trend": "empeorando",
      "last_seen": "2026-04-03T00:00:00Z"
    }
  ],
  "strong_concepts": [
    {
      "concept": "fotosíntesis",
      "error_rate": 0.10,
      "total_attempts": 10
    }
  ]
}
```

**Reglas de gaps:**
- Solo aparece como gap un concepto con `error_rate >= 0.3` y al menos 3 attempts
- `trend`: `"empeorando"` | `"mejorando"` | `"estable"` | `"sin_datos"`
- `dominant_error_type`: el tipo de error más frecuente
- `gaps` se ordena de mayor a menor `error_rate`

**UI de progreso:**

```
┌─────────────────────────────────────────────┐
│  📊 Progreso                                │
│                                              │
│  Total intentos: 45                          │
│  Aciertos: 30        Accuracy: 67%          │
│  ████████████░░░░░░░                         │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  🔴 Conceptos débiles                       │
│                                              │
│  fase oscura         78% error  📉 empeora  │
│  9 intentos · error dominante: conceptual   │
│                                              │
│  🟢 Conceptos fuertes                       │
│                                              │
│  fotosíntesis        10% error  📈 mejora   │
│  10 intentos                                 │
└─────────────────────────────────────────────┘
```

Cada concepto es tapeable → muestra historial detallado de los attempts de ese concepto.

---

## Referencia de DTOs y Headers

### Headers comunes

Todos los endpoints (excepto auth) requieren:
```
Authorization: Bearer <access_token>
Content-Type: application/json          // solo en POST, PATCH, PUT
```

### Tabla de DTOs

| DTO | Campos requeridos | Campos opcionales |
|-----|-------------------|-------------------|
| **RegisterDto** | `username` (str, min 4), `email` (email), `password` (str, min 8) | — |
| **LoginDto** | `email` (email), `password` (str) | — |
| **CreateStudyDto** | `title` (str, min 4), `description` (str, min 5) | — |
| **UpdateStudyDto** | — | `title` (str, min 4), `description` (str, min 5) |
| **CreateResourceDto** | `title` (str, min 3), `content` (str) | `sourceName` (str) |
| **UpdateResourceDto** | — | `title` (str, min 3), `content` (str), `sourceName` (str) |
| **CreateFlashcardDto** | `question` (str), `answer` (str), `conceptTags` (str[]), `resourceId` (UUID) | `type` ("open" \| "multiple-choice"), `options` ({correct, distractors[]}) |
| **CreateAttemptDto** | `isCorrect` (bool) | `userAnswer` (str), `errorType` (enum), `missingConcepts` (str[]), `incorrectConcepts` (str[]), `feedback` (str), `confidenceScore` (float 0-1) |

### Valores de `errorType` (enum)

| Valor | Cuándo usarlo |
|-------|---------------|
| `"conceptual"` | El estudiante tiene un concepto fundamentalmente equivocado |
| `"memoria"` | Sabía el concepto pero no lo recordó |
| `"confusion"` | Confundió un concepto con otro |
| `"incompleto"` | La respuesta es parcialmente correcta pero le faltó información |
| `null` | La respuesta es correcta |

### Mapa de auth por endpoint

| Endpoint | Método | Auth |
|----------|--------|------|
| `/auth/register` | POST | 🔓 Ninguno |
| `/auth/login` | POST | 🔓 Ninguno |
| `/auth/refresh` | POST | 🔑 Bearer `<refresh_token>` |
| `/auth/logout` | POST | 🔑 Bearer `<access_token>` |
| Todos los demás | * | 🔑 Bearer `<access_token>` |

---

## Integración con Foundation Models

| Uso | Input | Output | Dónde |
|-----|-------|--------|-------|
| **Generar flashcards** | Texto del recurso | Array de `CreateFlashcardDto` listo para mandar al backend | Pantalla 5 |
| **Evaluar respuesta abierta** | Pregunta + respuesta correcta + respuesta del usuario | `CreateAttemptDto` listo para mandar al backend | Pantalla 6 |
| **Explicar concepto** | Concepto erróneo + contexto del recurso | Explicación detallada (solo UI, no va al backend) | Pantalla 6 (feedback) |
| **Priorizar orden** | Flashcards + gaps | Flashcards reordenadas (solo UI, no va al backend) | Pantalla 6 (inicio) |

**Prompt de generación sugerido:**

```
Genera flashcards del siguiente contenido de estudio.
Devuelve un JSON array donde cada objeto tiene:

{
  "question": "pregunta",
  "answer": "respuesta completa",
  "type": "open" | "multiple-choice",
  "options": null | { "correct": "respuesta", "distractors": ["op1", "op2", "op3"] },
  "conceptTags": ["concepto1", "concepto2"]
}

Reglas:
- 50% preguntas abiertas, 50% opción múltiple
- conceptTags: máximo 3 tags por flashcard, conceptos clave
- Para opción múltiple: 1 correcta y 3 distractores plausibles
- Los distractores deben ser verosímiles, no absurdos

Contenido:
{resource.content}
```

> [!NOTE]
> Foundation Models debe devolver JSON que mapee directamente a `CreateFlashcardDto[]`. Swift solo necesita agregar el `resourceId` antes de mandar al backend.

**Prompt de evaluación sugerido:**

```
Eres un tutor evaluando una respuesta de estudio.

Pregunta: {question}
Respuesta correcta: {answer}
Respuesta del estudiante: {userAnswer}

Evalúa y devuelve JSON:
{
  "isCorrect": bool,
  "errorType": "conceptual" | "memoria" | "confusion" | "incompleto" | null,
  "missingConcepts": ["concepto que faltó"],
  "incorrectConcepts": ["concepto equivocado"],
  "feedback": "Explicación breve de qué estuvo bien/mal",
  "confidenceScore": 0.0-1.0
}
```

---

## Mejoras propuestas

Sobre tu flujo original, estas son las mejoras que considero más valiosas:

### 1. 🔄 Cantidad dinámica de flashcards (no fija en 18)

**Tu idea:** 9 abiertas + 9 múltiple choice siempre.

**Mejora:** Hacer la cantidad **proporcional al contenido**. Un recurso corto (300 palabras) no da para 18 flashcards buenas — generarás relleno. Un recurso largo (3,000 palabras) probablemente necesite más.

**Propuesta:**
- ~1 flashcard por cada 100-150 palabras de contenido
- Ratio configurable por el usuario: slider "Profundidad" → pocas/muchas
- Mantener el ratio 50/50 entre open y multiple_choice como default, pero permitir ajustarlo
- Mínimo: 6 (3+3), Máximo: 30 (15+15)

### 2. 📝 Pantalla de revisión antes de guardar

**Tu idea:** Generar y guardar directamente.

**Mejora:** Pantalla intermedia donde el usuario ve todas las flashcards generadas y puede:
- Eliminar las que no le convencen
- Editar pregunta/respuesta/opciones
- Regenerar una flashcard individual
- Ajustar conceptTags

Esto da **control al usuario** y mejora la calidad de las flashcards significativamente.

### 3. 🎯 Sesiones de práctica enfocadas

**Tu idea:** Practicar todas las flashcards de un estudio.

**Mejora:** Ofrecer modos de práctica:
- **Repaso SM-2** (default): solo las cards cuyo `nextReviewAt` ya pasó → `GET .../review-queue`
- **Conceptos débiles**: solo flashcards cuyos `conceptTags` aparecen en gaps con error_rate >= 0.5
- **Todo**: todas las flashcards del estudio
- **Por recurso**: filtrar por recurso específico con `?resource_id=uuid`

### 4. 📊 Resumen post-sesión

**Tu idea:** No mencionaste esto.

**Mejora:** Al terminar una sesión, mostrar:
- Cards acertadas vs total
- Conceptos donde mejoró vs empeoró
- Próxima fecha de repaso sugerida (basada en SM-2)
- Streak si practicó días consecutivos

Esto da dopamina y motiva a volver.

### 5. ⏱️ Respuestas con tiempo

**Tu idea:** No mencionaste timing.

**Mejora (opcional):** Medir cuánto tarda en responder cada flashcard. Esto sirve para:
- `confidenceScore` más preciso (respuesta correcta pero lenta = confianza media)
- Identificar cards que "sabe pero le cuesta recordar" vs "sabe al instante"
- El backend ya tiene el campo, solo falta mandarlo

> [!NOTE]
> Esto necesitaría un campo extra `responseTimeMs` en el DTO de attempt. No es prioritario para v1.

### 6. 🔊 Text-to-Speech para las preguntas

**Tu idea:** Speech-to-text para dictar respuestas.

**Mejora adicional:** También leer las preguntas en voz alta con `AVSpeechSynthesizer`. Útil para:
- Modo "manos libres" mientras caminas/cocinas
- Accesibilidad
- Refuerzo auditivo del aprendizaje

### 7. 📱 Widgets y notificaciones

**Tu idea:** No mencionaste esto.

**Mejora:**
- **Widget de iOS**: mostrar cuántas cards hay pendientes de repaso hoy
- **Notificaciones locales**: "Tienes 12 flashcards pendientes de Biología" basado en `nextReviewAt`
- No necesita backend — todo calculable con los datos en cache local

### 8. 🎮 Gamificación ligera

**Tu idea:** Gaps como stats.

**Mejora:** Expandir ese concepto:
- **Streak counter**: días consecutivos practicando
- **Mastery level por concepto**: ❌ → 🟡 → 🟢 → ⭐ basado en error_rate
- **Meta semanal**: "Revisa al menos 20 flashcards esta semana"
- Sin leaderboards ni comparaciones — la competencia es contra ti mismo

---

## Decisiones abiertas

> [!IMPORTANT]
> Estas son preguntas que impactan el desarrollo. Sería bueno definirlas antes de empezar Swift.

1. **¿Offline-first?** — ¿La app debe funcionar sin conexión? Si sí, necesitas cache local (Core Data / SwiftData) y sincronización cuando haya red. Foundation Models ya corre on-device, pero los datos de estudios/flashcards vienen del servidor.

2. **¿Cantidad fija o dinámica de flashcards?** — ¿Te convence la propuesta de hacerlo proporcional al contenido, o prefieres mantener el 9+9 fijo?

3. **¿Soporte multi-idioma en Speech-to-Text?** — ¿La app es solo en español, o el contenido puede ser en cualquier idioma?

4. **¿Quieres el timer de respuesta desde v1?** — Requiere un campo nuevo `responseTimeMs` en el DTO de attempt.

5. **¿Onboarding guiado?** — ¿Quieres un tutorial la primera vez que abre la app, o que sea self-explanatory?

---

## Resumen de endpoints usados por pantalla

| Pantalla | Endpoints |
|----------|-----------|
| Auth | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout` |
| Studies List | `GET /studies`, `POST /studies`, `DELETE /studies/:id` |
| Resources | `GET /studies/:id/resources`, `POST /studies/:id/resources`, `GET /resources/:id`, `PATCH /resources/:id` |
| Flashcards | `GET /studies/:id/flashcards`, `GET .../review-queue`, `POST /studies/:id/flashcards/batch`, `POST /studies/:id/flashcards` |
| Práctica | `GET /studies/:id/flashcards/review-queue`, `GET /studies/:id/gaps`, `POST /flashcards/:id/attempts` |
| Progreso | `GET /studies/:id/attempts`, `GET /studies/:id/gaps` |
