# API Reference — Study App Backend

> **Base URL:** `http://localhost:3000`
> **Auth:** Todos los endpoints excepto `/auth/*` requieren header `Authorization: Bearer <token>`
> **Content-Type:** `application/json`

---

## Tabla de contenidos

1. [Auth](#1-auth)
2. [Studies](#2-studies)
3. [Resources](#3-resources)
4. [Flashcards](#4-flashcards)
5. [Attempts](#5-attempts)
6. [Gaps](#6-gaps)
7. [Flujo completo](#flujo-completo)
8. [Códigos de error](#códigos-de-error)

---

## 1. Auth

Manejo de sesión. No requiere token.

### `POST /auth/register`

Registra un nuevo usuario. Rate limit: 5 requests / 15 min.

**Body:**
```json
{
  "email": "usuario@mail.com",
  "password": "12345678",
  "username": "Carlos"
}
```

**Response `201`:**
```json
{
  "access_token": "eyJhbGci...",
  "refresh_token": "eyJhbGci..."
}
```

---

### `POST /auth/login`

Inicia sesión. Rate limit: 5 requests / 15 min.

**Body:**
```json
{
  "email": "usuario@mail.com",
  "password": "12345678"
}
```

**Response `200`:**
```json
{
  "access_token": "eyJhbGci...",
  "refresh_token": "eyJhbGci..."
}
```

---

### `POST /auth/refresh`

Renueva tokens. Requiere `Authorization: Bearer <refresh_token>`. Rate limit: 10 requests / 1 min.

**Response `200`:**
```json
{
  "access_token": "eyJhbGci...",
  "refresh_token": "eyJhbGci..."
}
```

---

### `POST /auth/logout`

Cierra sesión e invalida el refresh token. Requiere `Authorization: Bearer <access_token>`.

**Response `200`:**
```json
{ "message": "Logged out" }
```

---

## 2. Studies

Un **Study** es el contenedor principal. Agrupa recursos, flashcards, attempts y gaps de un tema.

### `POST /studies`

Crea un nuevo estudio.

**Body:**
```json
{
  "title": "Biología celular",
  "description": "Apuntes del parcial 2"
}
```

**Response `201`:**
```json
{
  "id": "uuid",
  "title": "Biología celular",
  "description": "Apuntes del parcial 2"
}
```

---

### `GET /studies`

Lista todos los estudios del usuario. Soporta paginación.

**Query params opcionales:**
- `limit` (default: 10)
- `offset` (default: 0)

**Response `200`:**
```json
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

### `GET /studies/:studyId`

Detalle de un estudio específico.

**Response `200`:**
```json
{
  "id": "uuid",
  "title": "Biología celular",
  "description": "...",
  "createdAt": "2026-04-01T00:00:00Z"
}
```

---

### `DELETE /studies/:studyId`

Elimina el estudio y **todo su contenido** en cascada (resources, flashcards, attempts).

**Response `200`:** (sin body)

---

## 3. Resources

Un **Resource** es una nota o un PDF parseado. Siempre pertenece a un Study.

> Swift manda siempre texto plano — si es PDF, Vision Framework extrae el texto en el dispositivo antes de enviarlo.

### `POST /studies/:studyId/resources`

Crea un recurso dentro de un estudio.

**Body (nota):**
```json
{
  "title": "Clase 3 - Fotosíntesis",
  "content": "La fotosíntesis es el proceso por el cual las plantas..."
}
```

**Body (PDF parseado):**
```json
{
  "title": "Capítulo 4",
  "content": "Texto extraído del PDF por Vision Framework...",
  "sourceName": "capitulo4_biologia.pdf"
}
```

**Response `201`:**
```json
{
  "id": "uuid",
  "title": "Capítulo 4",
  "content": "...",
  "sourceName": "capitulo4_biologia.pdf",
  "createdAt": "2026-04-02T00:00:00Z"
}
```

---

### `GET /studies/:studyId/resources`

Lista todos los recursos de un estudio.

**Response `200`:**
```json
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

### `GET /resources/:id`

Detalle de un recurso específico.

**Response `200`:**
```json
{
  "id": "uuid",
  "title": "Clase 3 - Fotosíntesis",
  "content": "...",
  "sourceName": null,
  "createdAt": "2026-04-01T00:00:00Z"
}
```

---

### `PATCH /resources/:id`

Edita título o contenido de un recurso.

**Body:**
```json
{
  "title": "Clase 3 - Fotosíntesis (corregida)",
  "content": "Contenido actualizado..."
}
```

**Response `200`:** El recurso actualizado.

---

## 4. Flashcards

Una **Flashcard** pertenece a un Study y opcionalmente viene generada de un Resource. Las genera Foundation Models en Swift.

### `POST /studies/:studyId/flashcards`

Guarda una flashcard individual.

**Body:**
```json
{
  "resourceId": "uuid",
  "question": "¿Cuál es la función del cloroplasto?",
  "answer": "Realizar la fotosíntesis convirtiendo luz en energía química.",
  "type": "open",
  "conceptTags": ["cloroplasto", "fotosíntesis"]
}
```

**Response `201`:** La flashcard creada.

---

### `POST /studies/:studyId/flashcards/batch`

Guarda un lote de flashcards. **Usar justo después de que Foundation Models genere todas las flashcards de un recurso.**

**Body:**
```json
[
  {
    "resourceId": "uuid",
    "question": "¿Qué es la fotosíntesis?",
    "answer": "Proceso por el cual las plantas convierten luz en energía.",
    "type": "open",
    "conceptTags": ["fotosíntesis"]
  },
  {
    "resourceId": "uuid",
    "question": "¿Dónde ocurre la fase oscura?",
    "answer": "En el estroma del cloroplasto.",
    "type": "multiple_choice",
    "options": {
      "correct": "En el estroma del cloroplasto",
      "distractors": ["En la membrana tilacoide", "En el núcleo", "En el citoplasma"]
    },
    "conceptTags": ["fase oscura", "cloroplasto"]
  }
]
```

**Response `201`:** Array de flashcards creadas.

---

### `GET /studies/:studyId/flashcards`

Lista todas las flashcards de un estudio. Puede filtrar por recurso.

**Query params opcionales:**
- `resource_id=uuid` — solo flashcards generadas de ese recurso

**Response `200`:**
```json
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

### `GET /studies/:studyId/flashcards/review-queue`

Devuelve las flashcards que toca repasar **ahora** según el algoritmo SM-2. Incluye flashcards cuyo `nextReviewAt` ya pasó o es `null` (nunca repasadas). Ordenadas por `nextReviewAt` ascendente, las nunca repasadas primero.

**Llamar al inicio de cada sesión de práctica** para obtener las tarjetas que necesitan refuerzo.

**Response `200`:**
```json
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
```

> **Nota:** Si el array viene vacío, no hay flashcards pendientes de repaso.

---

## 5. Attempts

Un **Attempt** registra cada respuesta del usuario a una flashcard. Swift evalúa con Foundation Models y manda el resultado ya procesado — **el backend no evalúa nada**.

### `POST /flashcards/:flashcardId/attempts`

Guarda el resultado de una respuesta.

**Efecto secundario:** Al crear un attempt, el backend actualiza automáticamente los campos de **spaced repetition (SM-2)** de la flashcard:
- Si respondió **correctamente**: el intervalo crece progresivamente (1 → 6 → `interval × easeFactor`) y `easeFactor` sube +0.1
- Si respondió **incorrectamente**: el intervalo vuelve a 1 día y `easeFactor` baja -0.2 (mínimo 1.3)
- `nextReviewAt` se recalcula con el nuevo intervalo

**Body:**
```json
{
  "userAnswer": "El cloroplasto realiza la fotosíntesis usando la luz solar",
  "isCorrect": true,
  "errorType": null,
  "missingConcepts": [],
  "incorrectConcepts": [],
  "feedback": "Correcto. Mencionaste los conceptos clave.",
  "confidenceScore": 0.92
}
```

**Valores posibles de `errorType`:** `"conceptual"` | `"memoria"` | `"confusion"` | `"incompleto"` | `null`

**`confidenceScore`:** Float entre `0.0` y `1.0`

**Response `201`:** El attempt creado.

---

### `GET /studies/:studyId/attempts`

Historial de intentos de un estudio con métricas agregadas.

**Response `200`:**
```json
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
      "flashcard": { "id": "uuid", "question": "...", "conceptTags": [...] }
    }
  ]
}
```

---

## 6. Gaps

Los **Gaps** son lagunas de conocimiento calculadas matemáticamente a partir de los attempts acumulados. **Sin IA, solo agregación de datos.**

### `GET /studies/:studyId/gaps`

Calcula y devuelve el mapa de lagunas. **Llamar al iniciar cada sesión de práctica** para que Foundation Models priorice preguntas sobre conceptos débiles.

**Response `200`:**
```json
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

**Reglas:**
- Solo aparece como gap un concepto con `error_rate >= 0.3` y al menos 3 attempts
- `trend`: `"empeorando"` | `"mejorando"` | `"estable"` | `"sin_datos"`
- `dominant_error_type`: el tipo de error más frecuente entre los errores de ese concepto
- `gaps` se ordena de mayor a menor `error_rate`

---

## Flujo completo

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUJO DE LA APP                              │
└─────────────────────────────────────────────────────────────────────┘

 ══════════════════════════════════════════════════════════════════════
  1. AUTENTICACIÓN
 ══════════════════════════════════════════════════════════════════════

  POST /auth/register  ──→  Obtener access_token + refresh_token
  POST /auth/login     ──→  Obtener access_token + refresh_token
  POST /auth/refresh   ──→  Renovar tokens cuando access_token expire
  POST /auth/logout    ──→  Invalidar sesión

  ➜ Guardar ambos tokens. Usar access_token en header de cada request.
    Cuando expire, usar refresh_token para obtener nuevos tokens.

 ══════════════════════════════════════════════════════════════════════
  2. CREAR CONTENIDO DE ESTUDIO
 ══════════════════════════════════════════════════════════════════════

  POST /studies
    │
    │  ➜ Crear el contenedor del tema
    │
    ├──→ POST /studies/:studyId/resources
    │      │
    │      │  ➜ Agregar notas escritas o PDFs parseados por Vision
    │      │
    │      └──→ POST /studies/:studyId/flashcards/batch
    │             │
    │             │  ➜ Foundation Models genera flashcards del recurso
    │             │    Swift las manda todas juntas al backend
    │             │
    │             └──→ Las flashcards quedan ligadas al study + resource
    │
    └──→ POST /studies/:studyId/flashcards (individual, opcional)

 ══════════════════════════════════════════════════════════════════════
  3. SESIÓN DE PRÁCTICA
 ══════════════════════════════════════════════════════════════════════

  GET /studies/:studyId/gaps
    │
    │  ➜ Obtener mapa de lagunas ANTES de empezar
    │    Pasar gaps a Foundation Models para priorizar preguntas
    │
    ├──→ GET /studies/:studyId/flashcards
    │      │
    │      │  ➜ Cargar las flashcards del estudio
    │      │    Foundation Models decide el orden usando los gaps
    │      │
    │      └──→ Usuario responde cada flashcard
    │             │
    │             │  ➜ Foundation Models evalúa la respuesta
    │             │    Extrae: isCorrect, errorType, missingConcepts, etc.
    │             │
    │             └──→ POST /flashcards/:flashcardId/attempts
    │                    │
    │                    │  ➜ Guardar resultado evaluado
    │                    │    (repetir por cada flashcard respondida)
    │                    │
    │                    └──→ Los attempts alimentan los gaps
    │                         para la próxima sesión

 ══════════════════════════════════════════════════════════════════════
  4. CONSULTAR PROGRESO
 ══════════════════════════════════════════════════════════════════════

  GET /studies/:studyId/attempts
    │
    │  ➜ Historial completo + métricas (total, correct, accuracy)
    │    Útil para pantalla de estadísticas
    │
    └──→ GET /studies/:studyId/gaps
           │
           │  ➜ Ver qué conceptos son fuertes y cuáles débiles
           │    Útil para pantalla de progreso por concepto

 ══════════════════════════════════════════════════════════════════════
  5. GESTIÓN
 ══════════════════════════════════════════════════════════════════════

  GET /studies                        ──→ Listar estudios
  GET /studies/:studyId               ──→ Detalle de un estudio
  DELETE /studies/:studyId            ──→ Borrar estudio (cascade total)
  GET /studies/:studyId/resources     ──→ Listar recursos
  GET /resources/:id                  ──→ Detalle de un recurso
  PATCH /resources/:id                ──→ Editar recurso
```

---

## Relación entre entidades

```
User
 └── Study
      ├── Resource
      │    └── Flashcard (resource es opcional)
      ├── Flashcard
      │    └── Attempt
      └── Attempt
           └──→ alimenta → Gaps (cálculo en tiempo real)
```

- Un **User** tiene muchos **Studies**
- Un **Study** tiene muchos **Resources** y **Flashcards**
- Un **Resource** genera muchas **Flashcards** (relación opcional)
- Una **Flashcard** tiene muchos **Attempts**
- Los **Attempts** se agregan por `conceptTags` para calcular **Gaps**
- Borrar un Study borra todo en cascada
- Borrar un Resource pone `resource = null` en sus flashcards

---

## Códigos de error

| Código | Significado |
|--------|-------------|
| `400` | Validación fallida (campo faltante, tipo incorrecto, UUID inválido) |
| `401` | Token inválido o expirado |
| `429` | Rate limit alcanzado (esperar e intentar de nuevo) |
| `500` | Error interno del servidor |

**Formato de error:**
```json
{
  "statusCode": 400,
  "message": ["field must be a string"],
  "error": "Bad Request"
}
```
