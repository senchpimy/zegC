# zeg-C: C Compiler in Zig
![Badge](https://img.shields.io/badge/Zig-v0.12%2B-orange)

**zeg-C** es un proyecto experimental que busca implementar un compilador para el lenguaje **C**, escrito en **Zig**. Actualmente en fase inicial, el enfoque está en construir un analizador léxico y sintáctico interactivo tipo REPL para declaraciones y expresiones simples en C.

## Características

* REPL interactivo tipo `>>>` con continuación `...`.
* Análisis léxico de:

  * Declaraciones (`int x;`)
  * Asignaciones (`x = 4;`)
* Reconocimiento de tipos primitivos (`int`, `char`, `float`, etc.).
* Almacenamiento interno en `StringHashMap` con uniones (`Payload`) para manejar diferentes tipos.
* Múltiples instrucciones separadas por `;` en una sola línea.

## Objetivo

Implementar un compilador C minimalista en Zig, desde el análisis léxico y sintáctico hasta la generación de código, comenzando con un entorno interactivo para pruebas incrementales.

## Compilación

Requiere **Zig v0.15+**

```bash
zig build run
```

O directamente:

```bash
zig run main.zig
```

> ⚠️ El uso de `/dev/tty` implica que debe ejecutarse en un sistema tipo Unix/Linux con acceso a terminal cruda.

## Estado actual

**🚧 En desarrollo**

* Aún no soporta operaciones aritméticas ni expresiones complejas.
* Funcionalidad limitada al análisis de declaraciones y almacenamiento en memoria temporal.
* Futuras etapas incluirán análisis semántico y generación de código.

> El nombre **zeg-C** (léase como "sexy")
