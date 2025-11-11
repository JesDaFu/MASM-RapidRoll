; rapidroll.asm - Juego RapidRoll en MASM (texto 80x25)
; Controls: Flecha izquierda/derecha para mover, Espacio para saltar
; R para reiniciar cuando hay game over

.MODEL small
.STACK 100h
.DATA
; Video / pantalla
videoSeg dw 0B800h
screenCols equ 80
screenRows equ 25

; Strings del menú
menuStr  db 'RAPIDROLL - 1:Jugar  2:Salir$', 0
opt1Str  db '1: Jugar$', 0
opt2Str  db '2: Salir$', 0
gameOverStr db 'GAME OVER! Presiona R para reiniciar$'
scoreStr db 'Puntuacion: $'
levelStr db 'Nivel: $'

; Plataformas (usar bytes para indexación simple)
platformCount equ 8
platformsX db 10, 25, 40, 55, 20, 35, 50, 15
platformsY db 5, 8, 12, 15, 18, 21, 23, 3
platformsWidth db 8, 6, 10, 7, 9, 8, 6, 12

; Variables del jugador
playerX db 40
playerY db 20
playerVelocity db 0

score dw 0
level db 1
gameOver db 0
gameSpeed db 5
gravity db 1
jumpForce dw 250   ; usar dw para evitar problemas con bytes signados

; Estado del menú
gameState db 0

; Caracteres y colores usados para dibujo
platformChar db 223       ; carácter ▀ (barra de plataforma)
playerChar   db 2         ; carácter ☻ (jugador)
attrGreen    db 2Ah       ; verde brillante sobre negro
attrYellow   db 0Eh       ; amarillo brillante sobre negro

.CODE

; Macro para establecer posición del cursor
setCursor macro x, y
    push ax
    push bx
    push dx
    mov ah, 02h
    mov bh, 0
    mov dh, y
    mov dl, x
    int 10h
    pop dx
    pop bx
    pop ax
endm

; Macro para escribir texto
writeText macro text, x, y
    push ax
    push bx
    push dx
    setCursor x, y
    mov ah, 09h
    lea dx, text
    int 21h
    pop dx
    pop bx
    pop ax
endm

; Limpiar pantalla
clearScreen proc
    push ax
    push bx
    push cx
    push dx
    mov ax, 0600h  ; función scroll up
    mov bh, 07h    ; atributo normal
    mov cx, 0000h  ; esquina superior izquierda
    mov dx, 184Fh  ; esquina inferior derecha
    int 10h
    
    ; Posicionar cursor en 0,0
    mov ah, 02h
    mov bh, 0
    mov dx, 0000h
    int 10h
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
clearScreen endp

; Inicializar juego
initGame proc
    ; Estado jugador
    mov byte ptr playerX, 40
    mov byte ptr playerY, 20
    mov byte ptr playerVelocity, 0
    mov word ptr score, 0
    mov byte ptr level, 1
    mov byte ptr gameOver, 0
    mov byte ptr gameSpeed, 5

    ; Inicializar plataformas (llama al proc)
    call initPlatforms

    ret
initGame endp

; Inicializar plataformas - llena arrays platformsX/Y/Width con valores pseudoaleatorios simples
initPlatforms proc
    mov cx, platformCount    ; contador = número de plataformas
    xor si, si               ; índice (0..platformCount-1) - se usa como offset en bytes

init_pl_loop:
    ; pseudoaleatorio simple usando tick count
    mov ah, 0
    int 1Ah                  ; DX = tick count (BIOS)
    mov ax, dx
    and ax, 3Fh              ; 0..63
    add ax, 4                ; evitar 0 (posición X mínima)
    mov [platformsX + si], al

    ; Posición Y un poco escalonada
 mov ax, si
mov bl, 3
mul bl
add al, 5
mov [platformsY + si], al

    ; Ancho aleatorio 4..11
    mov ah, 0
    int 1Ah
    mov ax, dx
    and ax, 7
    add ax, 4
    mov [platformsWidth + si], al

    inc si                   ; siguiente índice (offset +1)
    loop init_pl_loop
    ret
initPlatforms endp

; Dibujar jugador
drawPlayer proc
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    
    mov ax, videoSeg
    mov es, ax
    
    ; Calcular posición en memoria de video
    mov al, playerY
    mov bl, screenCols
shl bl, 1       ; multiplica por 2 (equivale a screenCols * 2)
    mul bl
    mov bl, playerX
    mov bh, 0
    add ax, bx
    add ax, bx  ; x2 por atributo
    mov di, ax
    
    ; Dibujar jugador
    mov al, playerChar
    mov ah, attrYellow
    mov es:[di], ax
    
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret
drawPlayer endp

; Dibujar plataformas
drawPlatforms proc
    push ax
    push bx
    push cx
    push dx
    push si
    push es
    push di
    
    mov ax, videoSeg
    mov es, ax
    mov si, 0
    
platform_loop:
    ; Calcular posición Y de la plataforma
    mov al, platformsY[si]
    mov bl, screenCols * 2
    mul bl
    mov bx, ax
    
    ; Posición X inicial
    mov cl, platformsX[si]
    mov ch, 0
    
    ; Dibujar plataforma
    mov dl, platformsWidth[si]
    mov dh, 0
draw_platform:
    ; Calcular offset
    mov ax, bx      ; base Y
    mov di, cx      ; X actual
    add di, di      ; x2 por atributo
    add di, ax      ; posición final
    
    ; Dibujar carácter de plataforma
    mov al, platformChar
    mov ah, attrGreen
    mov es:[di], ax
    
    inc cx
    dec dl
    jnz draw_platform
    
    inc si
    cmp si, platformCount
    jl platform_loop
    
    pop di
    pop es
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
drawPlatforms endp

; Verificar colisión con plataformas
; Verificar colisión con plataformas (compara línea debajo del jugador)
checkCollision proc
    push bx
    push si
    push dx

    mov si, 0
    mov bl, playerX
    mov bh, 0

check_loop:
    ; calcular Y debajo del jugador
    mov al, playerY
    inc al
    cmp al, [platformsY + si]
    jne next_plat

    ; verificar X dentro del rango de la plataforma
    mov al, [platformsX + si]    ; x_inicial
    mov dl, [platformsWidth + si] ; ancho
    add al, dl
    dec al                        ; x_final = x_inicial + ancho - 1

    mov ah, playerX
    ; convertir AH:AL uso temporal: comparar AH(playerX) con x_inicial/ final
    ; simplificamos: obtener playerX en AL
    mov al, playerX
    cmp al, [platformsX + si]
    jb next_plat
    cmp al, [platformsX + si]
    jae .in_range_check

next_plat:
    inc si
    cmp si, platformCount
    jb check_loop
    jmp no_collision

.in_range_check:
    ; si llegó aquí, hay colisión (jugador sobre plataforma)
    ; rebotar: darle una pequeña velocidad de salto
    mov byte ptr playerVelocity, 3
    inc word ptr score
    jmp found

no_collision:
    ; no colisión, nada que hacer aquí (la gravedad ya aplicada en applyPhysics)
    jmp done_check

found:
    ; ajustar nivel si hace falta (ejemplo simple)
    cmp word ptr score, 10
    jb done_check
    mov byte ptr level, 2

done_check:
    pop dx
    pop si
    pop bx
    ret
checkCollision endp

; Mover plataformas
movePlatforms proc
    push si
    push ax
    
    mov si, 0
move_loop:
    ; Mover plataforma hacia arriba
    dec platformsY[si]
    
    ; Si la plataforma sale de la pantalla, reposicionarla abajo
    cmp platformsY[si], 0
    jg not_out_of_bounds
    
    ; Reposicionar en la parte inferior con nueva posición X
    mov ah, 0
    int 1Ah        ; obtener tick count
    mov ax, dx
    and ax, 3Fh    ; 0-63
    add ax, 10     ; desplazamiento mínimo
    mov platformsX[si], al
    
    mov platformsY[si], 24  ; fondo de la pantalla
    
    ; Nuevo ancho aleatorio
    mov ah, 0
    int 1Ah
    mov ax, dx
    and ax, 7      ; 0-7
    add ax, 4      ; 4-11
    mov platformsWidth[si], al

not_out_of_bounds:
    inc si
    cmp si, platformCount
    jl move_loop
    
    pop ax
    pop si
    ret
movePlatforms endp

; Procesar entrada del teclado
processInput proc
    push ax
    
    ; Verificar si hay tecla presionada
    mov ah, 01h
    int 16h
    jz input_end   ; no hay tecla
    
    ; Leer la tecla
    mov ah, 00h
    int 16h
    
    cmp ah, 4Bh    ; flecha izquierda
    je left_key
    cmp ah, 4Dh    ; flecha derecha
    je right_key
    cmp al, ' '    ; espacio
    je space_key
    cmp al, 'r'    ; R minúscula
    je r_key
    cmp al, 'R'    ; R mayúscula
    je r_key
    cmp al, 1Bh    ; ESC
    je esc_key
    jmp input_end

left_key:
    sub playerX, 2
    cmp playerX, 0
    jge input_end
    mov playerX, 0
    jmp input_end

right_key:
    add playerX, 2
    cmp playerX, 79
    jle input_end
    mov playerX, 79
    jmp input_end

space_key:
    mov playerVelocity, 250
    jmp input_end

r_key:
    cmp gameOver, 1
    jne input_end
    call initGame
    jmp input_end

esc_key:
    mov ax, 4C00h
    int 21h

input_end:
    pop ax
    ret
processInput endp

; Aplicar física al jugador
; Aplicar física al jugador (velocidad y gravedad simples)
applyPhysics proc
    push ax
    push bx

    ; Si hay impulso vertical (jumpForce usado como word), manejamos playerVelocity como byte
    ; Incrementar velocidad por gravedad
    mov al, playerVelocity
    add al, gravity
    mov playerVelocity, al

    ; Mover jugador verticalmente (usar byte aritmético)
    mov al, playerY
    add al, playerVelocity
    mov playerY, al

    ; Limitar por abajo
    mov al, playerY
    cmp al, 24
    jbe .ok
    mov byte ptr gameOver, 1

.ok:
    pop bx
    pop ax
    ret
applyPhysics endp

; Mostrar información en pantalla
drawUI proc
    ; Mostrar puntuación
    setCursor 2, 0
    mov ah, 09h
    lea dx, scoreStr
    int 21h
    
    ; Convertir score a ASCII y mostrar
    mov ax, score
    mov bl, 10
    div bl
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    mov al, ah
    add al, '0'
    mov dl, al
    int 21h
    
    ; Mostrar nivel
    setCursor 70, 0
    mov ah, 09h
    lea dx, levelStr
    int 21h
    
    mov dl, level
    add dl, '0'
    mov ah, 02h
    int 21h
    
    ; Mostrar game over si es necesario
    cmp gameOver, 1
    jne ui_end
    
    setCursor 25, 12
    mov ah, 09h
    lea dx, gameOverStr
    int 21h

ui_end:
    ret
drawUI endp

; Mostrar menú principal
showMenu proc
menu_loop:
    call clearScreen
    
    setCursor 28, 10
    mov ah, 09h
    lea dx, menuStr
    int 21h

wait_key:
    mov ah, 01h
    int 16h
    jz wait_key
    mov ah, 00h
    int 16h

    cmp al, '1'
    je start_game
    cmp al, '2'
    je exit_game
    cmp al, 1Bh
    je exit_game
    jmp menu_loop

start_game:
    call initGame
    ret

exit_game:
    mov ax, 4C00h
    int 21h
showMenu endp


; Bucle principal del juego
main proc
    mov ax, @data
    mov ds, ax
    
    ; Configurar modo video 80x25
    mov ax, 0003h
    int 10h
    
    call showMenu
    
game_loop:
    call clearScreen
    call processInput
    
    cmp gameOver, 1
    je draw_only
    
    call applyPhysics
    call checkCollision
    call movePlatforms

draw_only:
    call drawPlatforms
    call drawPlayer
    call drawUI
    
    ; Delay para control de velocidad
    mov cx, 0
    mov dx, 8000h
    mov ah, 86h
    int 15h
    
    jmp game_loop

    mov ax, 4C00h
    int 21h
main endp

end main