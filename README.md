🎮 RapidRoll (MASM Assembly Game)

RapidRoll.asm es una recreación en ensamblador x86 del clásico minijuego Rapid Roll — totalmente en modo texto (80x25).
Fue desarrollado en MASM y puede ejecutarse en DOSBox o mediante extensiones de ensamblador en Visual Studio Code.

🕹️ Características

Jugabilidad tipo arcade: evita caer moviéndote entre plataformas.

Movimiento fluido del jugador con física de gravedad y salto.

Colisiones detectadas en modo texto.

Menú principal interactivo.

Modo de puntuación y niveles.

Diseño optimizado para modo video 03h (texto VGA 80x25).

⚙️ Controles
Tecla	Acción
← / A	Mover izquierda
→ / D	Mover derecha
Espacio	Saltar
R	Reiniciar después de Game Over
ESC	Salir del juego
🧩 Requisitos

MASM32 o TASM (para ensamblar y linkear)

DOSBox (recomendado)

Alternativamente: Visual Studio Code con la extensión “x86 and x64 Assembly”

Entorno en modo real DOS (16 bits)

🚀 Ejecución
En DOSBox

Monta el directorio donde está tu código:

mount c c:\ruta\al\proyecto
c:


Compila y ejecuta:

masm rapidroll.asm;
link rapidroll.obj;
rapidroll.exe

En Visual Studio Code

Instala la extensión: MASM/TASM x86 Assembly.

Configura el ensamblador MASM como tarea de compilación.

Ejecuta o depura directamente el código desde VS Code.

🧠 Estructura del código

main — bucle principal del juego

showMenu — menú de inicio

processInput — control del teclado

applyPhysics — movimiento y gravedad del jugador

checkCollision — detección de plataformas

drawPlayer / drawPlatforms — renderizado en memoria de video

drawUI — puntuación, nivel y texto de Game Over
