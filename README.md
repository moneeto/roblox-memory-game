# Juego de Memoria — Centro Recreativo (v2)

Sistema multi-mesa con tablero **físico 3D** sobre cada mesa.

## Mesas

| Tipo | Cantidad | Capacidad | Reglas |
|---|---|---|---|
| **Solo** | 3 | 1 jugador | Sin turnos, métricas: intentos + tiempo |
| **Versus** | 6 | 2 jugadores | Turnos alternados, clásico memory |

Cada mesa es una `GameInstance` independiente descubierta vía `CollectionService` tag `"MemoryTable"`.

## Arquitectura

```
src/server/
  GameInstance.luau    -- clase: estado y reglas por mesa
  TableManager.luau    -- registra mesas, conecta remotes y asientos
  BoardBuilder.luau    -- cartas físicas 3D sobre BoardOrigin
  PlazaBuilder.luau    -- genera plaza + 9 mesas taggeadas

src/client/
  CardInteraction.luau   -- ClickDetector → RequestFlip(tableId, index)
  CardAnimations3D.luau  -- animaciones 3D
  TableHud.luau          -- HUD mínimo (salir, resultados)
```

## Cómo probar

1. `rojo serve` + Play en Studio
2. Sentate en una mesa **Solo** (1 silla) o **Versus** (2 sillas enfrentadas)
3. El indicador `0/1` o `0/2` pasa a verde al completar ocupación
4. Click en las cartas físicas sobre la mesa

## Mapa custom

En `PlazaConfig.luau`:

```lua
PlazaConfig.BUILD_ENVIRONMENT = false
PlazaConfig.DESTROY_BASEPLATE = false
PlazaConfig.BASE_Y = 20
```

Creá modelos en Studio con:
- Tag `MemoryTable`
- Attribute `Mode` = `"Solo"` o `"Versus"`
- Hijos: `Seat1`, `Seat2` (solo Versus), `BoardOrigin`, `TableTop`

## Sonidos

Editá `src/shared/SoundConfig.luau` — ver comentarios en el archivo.
