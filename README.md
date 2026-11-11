# Gastos Compartidos

App Android en Flutter para registrar gastos de un grupo (piso, viaje o evento) **por voz** y saldarlos con **el mínimo de pagos**. Prototipo del Seminario de Emprendimiento e Innovación (Pascual Bravo).

Todo se guarda en el teléfono (sin servidor ni cuentas). El usuario de la app es quien administra el grupo.

## Qué hace

| Pantalla | Qué hace |
|---|---|
| Bienvenida | Pide tu nombre (y celular opcional). Se puede entrar con datos de ejemplo. |
| Inicio | Tu balance (por moneda), tus grupos y el botón para registrar por voz. Campana con avisos. |
| Nuevo / editar grupo | Nombre, tipo (Piso, Viaje, Evento), moneda e integrantes: desde contactos o escritos a mano. Invitación por WhatsApp, o por el menú de compartir si la persona no tiene celular. |
| Registro por voz | Usa el reconocimiento de voz de Android. Gemini extrae monto, concepto, categoría, quién pagó y entre quiénes; si no hay clave o internet, lo hacen reglas locales. |
| Revisar gasto | Confirmar o corregir los datos. División en partes iguales, por montos o por porcentaje. Opción de repetir el gasto cada semana, quincena, mes o año. |
| Detalle del grupo | Gastos del mes, tu saldo, la lista de gastos (marcados “POR VOZ”), los gastos recurrentes y los pagos. Los gastos se pueden editar o borrar. |
| Saldar cuentas | Liquidación mínima: quién le paga a quién. Registra pagos completos o parciales. Recordatorio por WhatsApp a quien debe, o resumen para el chat del grupo. |
| Pago registrado | Confirma el pago, muestra lo que queda pendiente y tu saldo. |
| Perfil | Editar nombre y celular, ver si la IA está activa, cargar datos de ejemplo o borrar todo. |

Los avisos dentro de la app son de tres tipos: gastos recurrentes creados solos, pagos registrados y saldos por cobrar (máximo uno al día por grupo).

## Requisitos

- Flutter 3.47 o superior (Dart 3.13).
- Android SDK con licencias aceptadas (`flutter doctor --android-licenses`).
- Teléfono Android 7.0 o superior con la app de Google (para el reconocimiento de voz).

## Clave de Gemini (opcional)

Sin clave la app funciona y lee la frase con reglas locales. Para usar IA:

1. Crea una clave gratuita en [Google AI Studio](https://aistudio.google.com/apikey).
2. Copia `env.example.json` como `env.json` (este archivo no se sube a git) y pega la clave:
   ```json
   { "GEMINI_API_KEY": "tu-clave", "GEMINI_MODEL": "gemini-flash-latest" }
   ```
3. Ejecuta o compila siempre con `--dart-define-from-file=env.json`. En VS Code, la configuración “Gastos Compartidos” ya lo incluye.

Ten en cuenta lo siguiente:
- Solo se envía a Gemini el **texto** transcrito y los nombres del grupo; el audio no sale del teléfono.
- En el nivel gratuito, Google puede usar esos datos para mejorar sus productos.
- La clave queda dentro de la APK y alguien con conocimientos podría extraerla. Para un prototipo es aceptable. En producción, la llamada debería pasar por un servidor propio.
- Si el modelo `gemini-flash-latest` cambia de nombre, ajusta `GEMINI_MODEL` en `env.json`.

## Comandos

```bash
flutter pub get
dart run build_runner build      # regenera lib/data/database.g.dart si cambias tablas
flutter test                     # 32 pruebas
flutter run --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
```

La APK queda en `build/app/outputs/flutter-apk/app-release.apk`. Está firmada con la clave de depuración: sirve para instalar en teléfonos de prueba, pero no para publicar en Play Store.

## Estructura

```
lib/
  core/        moneda (formato y lectura de montos), configuración
  domain/      reglas puras: división, liquidación mínima, recurrencia, categorías
  data/        base de datos Drift (SQLite), repositorio, datos de ejemplo
  voice/       analizador por reglas, extractor Gemini y combinación de ambos
  state/       Cubits (flutter_bloc): app, grupos, avisos, formularios, voz
  screens/     pantallas
  ui/          tema, íconos SVG del mockup, componentes, WhatsApp/compartir
test/          pruebas de dominio, analizador de voz, repositorio y pantallas
```

## Decisiones de diseño

- **Liquidación mínima.** Algoritmo voraz: quien más debe le paga a quien más le deben. Con los datos del mockup da 3 pagos en lugar de 6 transferencias cruzadas.
- **Montos.** Se guardan como enteros en la unidad mínima de la moneda (pesos o centavos). Los pesos sobrantes de una división se asignan en orden, empezando por “Tú”.
- **Moneda.** Cada grupo tiene la suya y no hay conversión. Se bloquea cuando el grupo ya tiene gastos.
- **Integrantes.** No se puede quitar a alguien con gastos o pagos registrados en el grupo.
- **Gastos recurrentes.** Se generan al abrir la app o al volver a ella. Un gasto mensual del día 31 cae el 30 o el 28 según el mes, y vuelve al 31 cuando el mes lo tiene.
- **Tipografía.** Arimo (misma métrica que Arial) y Cousine (monoespaciada, en lugar de Consolas), con licencia Apache 2.0, porque Arial y Consolas no se pueden incluir en una app.
